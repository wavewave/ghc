module Vectorise( vectorise )
where

#include "HsVersions.h"

import VectMonad
import VectUtils
import VectType

import DynFlags
import HscTypes

import CoreLint             ( showPass, endPass )
import CoreSyn
import CoreUtils
import CoreFVs
import SimplMonad           ( SimplCount, zeroSimplCount )
import Rules                ( RuleBase )
import DataCon
import TyCon
import Type
import FamInstEnv           ( extendFamInstEnvList )
import InstEnv              ( extendInstEnvList )
import Var
import VarEnv
import VarSet
import Name                 ( mkSysTvName, getName )
import NameEnv
import Id
import MkId                 ( unwrapFamInstScrut )
import OccName

import DsMonad hiding (mapAndUnzipM)
import DsUtils              ( mkCoreTup, mkCoreTupTy )

import PrelNames
import TysWiredIn
import TysPrim              ( intPrimTy )
import BasicTypes           ( Boxity(..) )

import Outputable
import FastString
import Control.Monad        ( liftM, liftM2, mapAndUnzipM )

vectorise :: HscEnv -> UniqSupply -> RuleBase -> ModGuts
          -> IO (SimplCount, ModGuts)
vectorise hsc_env _ _ guts
  = do
      showPass dflags "Vectorisation"
      eps <- hscEPS hsc_env
      let info = hptVectInfo hsc_env `plusVectInfo` eps_vect_info eps
      Just (info', guts') <- initV hsc_env guts info (vectModule guts)
      endPass dflags "Vectorisation" Opt_D_dump_vect (mg_binds guts')
      return (zeroSimplCount dflags, guts' { mg_vect_info = info' })
  where
    dflags = hsc_dflags hsc_env

vectModule :: ModGuts -> VM ModGuts
vectModule guts
  = do
      (types', fam_insts, pa_insts) <- vectTypeEnv (mg_types guts)
      
      let insts         = map painstInstance pa_insts
          fam_inst_env' = extendFamInstEnvList (mg_fam_inst_env guts) fam_insts
          inst_env'     = extendInstEnvList (mg_inst_env guts) insts
      updGEnv (setInstEnvs inst_env' fam_inst_env')
     
      dicts  <- mapM buildPADict pa_insts 
      binds' <- mapM vectTopBind (mg_binds guts)
      return $ guts { mg_types        = types'
                    , mg_binds        = Rec (concat dicts) : binds'
                    , mg_inst_env     = inst_env'
                    , mg_fam_inst_env = fam_inst_env'
                    , mg_insts        = mg_insts guts ++ insts
                    , mg_fam_insts    = mg_fam_insts guts ++ fam_insts
                    }

vectTopBind :: CoreBind -> VM CoreBind
vectTopBind b@(NonRec var expr)
  = do
      var'  <- vectTopBinder var
      expr' <- vectTopRhs expr
      hs    <- takeHoisted
      return . Rec $ (var, expr) : (var', expr') : hs
  `orElseV`
    return b

vectTopBind b@(Rec bs)
  = do
      vars'  <- mapM vectTopBinder vars
      exprs' <- mapM vectTopRhs exprs
      hs     <- takeHoisted
      return . Rec $ bs ++ zip vars' exprs' ++ hs
  `orElseV`
    return b
  where
    (vars, exprs) = unzip bs

vectTopBinder :: Var -> VM Var
vectTopBinder var
  = do
      vty <- vectType (idType var)
      name <- cloneName mkVectOcc (getName var)
      let var' | isExportedId var = Id.mkExportedLocalId name vty
               | otherwise        = Id.mkLocalId         name vty
      defGlobalVar var var'
      return var'
    
vectTopRhs :: CoreExpr -> VM CoreExpr
vectTopRhs = liftM fst . closedV . vectPolyExpr (panic "Empty lifting context") . freeVars

-- ----------------------------------------------------------------------------
-- Bindings

vectBndr :: Var -> VM (Var, Var)
vectBndr v
  = do
      vty <- vectType (idType v)
      lty <- mkPArrayType vty
      let vv = v `Id.setIdType` vty
          lv = v `Id.setIdType` lty
      updLEnv (mapTo vv lv)
      return (vv, lv)
  where
    mapTo vv lv env = env { local_vars = extendVarEnv (local_vars env) v (vv, lv) }

vectBndrIn :: Var -> VM a -> VM (Var, Var, a)
vectBndrIn v p
  = localV
  $ do
      (vv, lv) <- vectBndr v
      x <- p
      return (vv, lv, x)

vectBndrsIn :: [Var] -> VM a -> VM ([Var], [Var], a)
vectBndrsIn vs p
  = localV
  $ do
      (vvs, lvs) <- mapAndUnzipM vectBndr vs
      x <- p
      return (vvs, lvs, x)

-- ----------------------------------------------------------------------------
-- Expressions

capply :: (CoreExpr, CoreExpr) -> (CoreExpr, CoreExpr) -> VM (CoreExpr, CoreExpr)
capply (vfn, lfn) (varg, larg)
  = do
      apply  <- builtin applyClosureVar
      applyP <- builtin applyClosurePVar
      return (mkApps (Var apply)  [Type arg_ty, Type res_ty, vfn, varg],
              mkApps (Var applyP) [Type arg_ty, Type res_ty, lfn, larg])
  where
    fn_ty            = exprType vfn
    (arg_ty, res_ty) = splitClosureTy fn_ty

vectVar :: Var -> Var -> VM (CoreExpr, CoreExpr)
vectVar lc v
  = do
      r <- lookupVar v
      case r of
        Local (vv,lv) -> return (Var vv, Var lv)
        Global vv     -> do
                           let vexpr = Var vv
                           lexpr <- replicatePA vexpr (Var lc)
                           return (vexpr, lexpr)

vectPolyVar :: Var -> Var -> [Type] -> VM (CoreExpr, CoreExpr)
vectPolyVar lc v tys
  = do
      vtys <- mapM vectType tys
      r <- lookupVar v
      case r of
        Local (vv, lv) -> liftM2 (,) (polyApply (Var vv) vtys)
                                     (polyApply (Var lv) vtys)
        Global poly    -> do
                            vexpr <- polyApply (Var poly) vtys
                            lexpr <- replicatePA vexpr (Var lc)
                            return (vexpr, lexpr)

vectPolyExpr :: Var -> CoreExprWithFVs -> VM (CoreExpr, CoreExpr)
vectPolyExpr lc expr
  = polyAbstract tvs $ \mk_lams ->
    -- FIXME: shadowing (tvs in lc)
    do
      (vmono, lmono) <- vectExpr lc mono
      return $ (mk_lams vmono, mk_lams lmono)
  where
    (tvs, mono) = collectAnnTypeBinders expr  
                
vectExpr :: Var -> CoreExprWithFVs -> VM (CoreExpr, CoreExpr)
vectExpr lc (_, AnnType ty)
  = do
      vty <- vectType ty
      return (Type vty, Type vty)

vectExpr lc (_, AnnVar v) = vectVar lc v

vectExpr lc (_, AnnLit lit)
  = do
      let vexpr = Lit lit
      lexpr <- replicatePA vexpr (Var lc)
      return (vexpr, lexpr)

vectExpr lc (_, AnnNote note expr)
  = do
      (vexpr, lexpr) <- vectExpr lc expr
      return (Note note vexpr, Note note lexpr)

vectExpr lc e@(_, AnnApp _ arg)
  | isAnnTypeArg arg
  = vectTyAppExpr lc fn tys
  where
    (fn, tys) = collectAnnTypeArgs e

vectExpr lc (_, AnnApp fn arg)
  = do
      fn'  <- vectExpr lc fn
      arg' <- vectExpr lc arg
      capply fn' arg'

vectExpr lc (_, AnnCase expr bndr ty alts)
  = panic "vectExpr: case"

vectExpr lc (_, AnnLet (AnnNonRec bndr rhs) body)
  = do
      (vrhs, lrhs) <- vectPolyExpr lc rhs
      (vbndr, lbndr, (vbody, lbody)) <- vectBndrIn bndr (vectExpr lc body)
      return (Let (NonRec vbndr vrhs) vbody,
              Let (NonRec lbndr lrhs) lbody)

vectExpr lc (_, AnnLet (AnnRec prs) body)
  = do
      (vbndrs, lbndrs, (vrhss, vbody, lrhss, lbody)) <- vectBndrsIn bndrs vect
      return (Let (Rec (zip vbndrs vrhss)) vbody,
              Let (Rec (zip lbndrs lrhss)) lbody)
  where
    (bndrs, rhss) = unzip prs
    
    vect = do
             (vrhss, lrhss) <- mapAndUnzipM (vectExpr lc) rhss
             (vbody, lbody) <- vectPolyExpr lc body
             return (vrhss, vbody, lrhss, lbody)

vectExpr lc e@(_, AnnLam bndr body)
  | isTyVar bndr = pprPanic "vectExpr" (ppr $ deAnnotate e)

vectExpr lc (fvs, AnnLam bndr body)
  = do
      tyvars <- localTyVars
      info <- mkCEnvInfo fvs bndr body
      (poly_vfn, poly_lfn) <- mkClosureFns info tyvars bndr body

      vfn_var <- hoistExpr FSLIT("vfn") poly_vfn
      lfn_var <- hoistExpr FSLIT("lfn") poly_lfn

      let (venv, lenv) = mkClosureEnvs info (Var lc)

      let env_ty = cenv_vty info

      pa_dict <- paDictOfType env_ty

      arg_ty <- vectType (varType bndr)
      res_ty <- vectType (exprType $ deAnnotate body)

      -- FIXME: move the functions to the top level
      mono_vfn <- polyApply (Var vfn_var) (mkTyVarTys tyvars)
      mono_lfn <- polyApply (Var lfn_var) (mkTyVarTys tyvars)

      mk_clo <- builtin mkClosureVar
      mk_cloP <- builtin mkClosurePVar

      let vclo = Var mk_clo  `mkTyApps` [arg_ty, res_ty, env_ty]
                             `mkApps`   [pa_dict, mono_vfn, mono_lfn, venv]
          
          lclo = Var mk_cloP `mkTyApps` [arg_ty, res_ty, env_ty]
                             `mkApps`   [pa_dict, mono_vfn, mono_lfn, lenv]

      return (vclo, lclo)

data CEnvInfo = CEnvInfo {
               cenv_vars         :: [Var]
             , cenv_values       :: [(CoreExpr, CoreExpr)]
             , cenv_vty          :: Type
             , cenv_lty          :: Type
             , cenv_repr_tycon   :: TyCon
             , cenv_repr_tyargs  :: [Type]
             , cenv_repr_datacon :: DataCon
             }

mkCEnvInfo :: VarSet -> Var -> CoreExprWithFVs -> VM CEnvInfo
mkCEnvInfo fvs arg body
  = do
      locals <- readLEnv local_vars
      let
          (vars, vals) = unzip
                 [(var, (Var v, Var v')) | var      <- varSetElems fvs
                                         , Just (v,v') <- [lookupVarEnv locals var]]
      vtys <- mapM (vectType . varType) vars

      (vty, repr_tycon, repr_tyargs, repr_datacon) <- mk_env_ty vtys
      lty <- mkPArrayType vty
      
      return $ CEnvInfo {
                 cenv_vars         = vars
               , cenv_values       = vals
               , cenv_vty          = vty
               , cenv_lty          = lty
               , cenv_repr_tycon   = repr_tycon
               , cenv_repr_tyargs  = repr_tyargs
               , cenv_repr_datacon = repr_datacon
               }
  where
    mk_env_ty [vty]
      = return (vty, error "absent cinfo_repr_tycon"
                   , error "absent cinfo_repr_tyargs"
                   , error "absent cinfo_repr_datacon")

    mk_env_ty vtys
      = do
          let ty = mkCoreTupTy vtys
          (repr_tc, repr_tyargs) <- lookupPArrayFamInst ty
          let [repr_con] = tyConDataCons repr_tc
          return (ty, repr_tc, repr_tyargs, repr_con)

    

mkClosureEnvs :: CEnvInfo -> CoreExpr -> (CoreExpr, CoreExpr)
mkClosureEnvs info lc
  | [] <- vals
  = (Var unitDataConId, mkApps (Var $ dataConWrapId (cenv_repr_datacon info))
                               [lc, Var unitDataConId])

  | [(vval, lval)] <- vals
  = (vval, lval)

  | otherwise
  = (mkCoreTup vvals, Var (dataConWrapId $ cenv_repr_datacon info)
                      `mkTyApps` cenv_repr_tyargs info
                      `mkApps`   (lc : lvals))

  where
    vals = cenv_values info
    (vvals, lvals) = unzip vals

mkClosureFns :: CEnvInfo -> [TyVar] -> Var -> CoreExprWithFVs
             -> VM (CoreExpr, CoreExpr)
mkClosureFns info tyvars arg body
  = closedV
  . polyAbstract tyvars
  $ \mk_tlams ->
  do
    (vfn, lfn) <- mkClosureMonoFns info arg body
    return (mk_tlams vfn, mk_tlams lfn)

mkClosureMonoFns :: CEnvInfo -> Var -> CoreExprWithFVs -> VM (CoreExpr, CoreExpr)
mkClosureMonoFns info arg body
  = do
      lc_bndr <- newLocalVar FSLIT("lc") intPrimTy
      (varg : vbndrs, larg : lbndrs, (vbody, lbody))
        <- vectBndrsIn (arg : cenv_vars info)
                       (vectExpr lc_bndr body)

      venv_bndr <- newLocalVar FSLIT("env") vty
      lenv_bndr <- newLocalVar FSLIT("env") lty

      let vcase = bind_venv (Var venv_bndr) vbody vbndrs
      lcase <- bind_lenv (Var lenv_bndr) lbody lc_bndr lbndrs
      return (mkLams [venv_bndr, varg] vcase, mkLams [lenv_bndr, larg] lcase)
  where
    vty = cenv_vty info
    lty = cenv_lty info

    arity = length (cenv_vars info)

    bind_venv venv vbody []      = vbody
    bind_venv venv vbody [vbndr] = Let (NonRec vbndr venv) vbody
    bind_venv venv vbody vbndrs
      = Case venv (mkWildId vty) (exprType vbody)
             [(DataAlt (tupleCon Boxed arity), vbndrs, vbody)]

    bind_lenv lenv lbody lc_bndr [lbndr]
      = do
          len <- lengthPA (Var lbndr)
          return . Let (NonRec lbndr lenv)
                 $ Case len
                        lc_bndr
                        (exprType lbody)
                        [(DEFAULT, [], lbody)]

    bind_lenv lenv lbody lc_bndr lbndrs
      = let scrut = unwrapFamInstScrut (cenv_repr_tycon info)
                                       (cenv_repr_tyargs info)
                                       lenv
            lbndrs' | null lbndrs = [mkWildId unitTy]
                    | otherwise   = lbndrs
        in
        return
      $ Case scrut
             (mkWildId (exprType scrut))
             (exprType lbody)
             [(DataAlt (cenv_repr_datacon info), lc_bndr : lbndrs', lbody)]
          
vectTyAppExpr :: Var -> CoreExprWithFVs -> [Type] -> VM (CoreExpr, CoreExpr)
vectTyAppExpr lc (_, AnnVar v) tys = vectPolyVar lc v tys
vectTyAppExpr lc e tys = pprPanic "vectTyAppExpr" (ppr $ deAnnotate e)

