# 1. To make standard library:
#
# e.g. from lib/std directory:
#	$(MAKE) way=ilx-Onot-mono std.ilx-Onot.mono.dll std.ilx-Onot.mono.vlb
#	$(MAKE) way=ilx-O-mono  std.ilx-O.mono.dll std.ilx-O.mono.vlb
#	$(MAKE) way=ilx-Onot-generic std.ilx-Onot.generic.dll
#
# 2. To make tests:
#
# e.g. from ilxGen/tests directory:
#
#  $ make -n way=ilx-Onot-mono test1.ilx-Onot.mono.retail.run 
#
#  $ make -n way=ilx-Onot-mono test1-nostdlib.ilx-Onot.mono.retail.run HC_OPTS="-fno-implicit-prelude -fglasgow-exts"
#


# Add all the ILX ways so dependencies get made correctly.
# (n.b. Actually we only need to add "ilx-Onot" and "ilx-O" for the 
#       GHC --> ILX dependencies, as these are the portions of the ILX
#       ways that are relevant in terms of GHC options,
#       but we list some of the others anyway.  Also note that
#       there are no dependencies required for the ILX --> IL or
#       IL --> CLR phases as these operate on the "standalone"
#       ILX and IL files).
#
GhcLibWays+= ilx-Onot-mono ilx-Onot ilx-O ilx-O-mono
GhcWithIlx=YES

ILXized=YES

# These are common to all the ILX ways
GHC_ILX_OPTS=-filx  -fruntime-types -DILX -DNO_BIG_TUPLES


# Each set of args below defines one ILX way.
ALL_WAYS+=ilx-Onot-generic
WAY_ilx-Onot-generic_NAME=ILX with Haskell Optimizer Off to run on Generic CLR
WAY_ilx-Onot-generic_HC_OPTS=-buildtag ilx-Onot  $(GHC_ILX_OPTS) -Onot 
WAY_ilx-Onot-generic_ILX2IL_OPTS=--generic 
WAY_ilx-Onot-generic_ILX=YES

ALL_WAYS+=ilx-Onot-fullgeneric-verifiable
WAY_ilx-Onot-fullgeneric-verifiable_NAME=ILX with Haskell Optimizer Off to run on Generic CLR
WAY_ilx-Onot-fullgeneric-verifiable_HC_OPTS=-buildtag ilx-Onot $(GHC_ILX_OPTS) -Onot 
WAY_ilx-Onot-fullgeneric-verifiable_ILX2IL_OPTS=--fullgeneric  --verifiable
WAY_ilx-Onot-fullgeneric-verifiable_ILX=YES

ALL_WAYS+=ilx-Onot-repgeneric-verifiable
WAY_ilx-Onot-repgeneric-verifiable_NAME=ILX with Haskell Optimizer Off to run on Generic CLR
WAY_ilx-Onot-repgeneric-verifiable_HC_OPTS=-buildtag ilx-Onot $(GHC_ILX_OPTS) -Onot 
WAY_ilx-Onot-repgeneric-verifiable_ILX2IL_OPTS=--repgeneric  --verifiable
WAY_ilx-Onot-repgeneric-verifiable_ILX=YES

ALL_WAYS+=ilx-O-generic
WAY_ilx-O-generic_NAME=ILX with Haskell Optimizer On to run on Generic CLR
WAY_ilx-O-generic_HC_OPTS=-buildtag ilx-O $(GHC_ILX_OPTS) -O 
WAY_ilx-O-generic_ILX2IL_OPTS=--generic 
WAY_ilx-O-generic_ILX=YES

ALL_WAYS+=ilx-Onot-mono
WAY_ilx-Onot-mono_NAME=ILX with Haskell Optimizer Off to run on V1 CLR
WAY_ilx-Onot-mono_HC_OPTS=-buildtag ilx-Onot $(GHC_ILX_OPTS) -Onot 
WAY_ilx-Onot-mono_ILX2IL_OPTS=--mono 
WAY_ilx-Onot-mono_ILX=YES

ALL_WAYS+=ilx-Onot-mono-verifiable
WAY_ilx-Onot-mono-verifiable_NAME=ILX with Haskell Optimizer Off to run on V1 CLR, verifiable code (CURRENTLY WILL NOT RUN BECAUSE OF LACK OF HIGHER KINDED TYPE PARAMETERS BUT IS USEFUL TO FIND BUGS USING THE VERIFIER)
WAY_ilx-Onot-mono-verifiable_HC_OPTS=-buildtag ilx-Onot $(GHC_ILX_OPTS) -Onot 
WAY_ilx-Onot-mono-verifiable_ILX2IL_OPTS=--mono  --verifiable
WAY_ilx-Onot-mono-verifiable_ILX=YES

ALL_WAYS+=ilx-O-mono
WAY_ilx-O-mono_NAME=ILX with Haskell Optimizer On to run on V1 CLR
WAY_ilx-O-mono_HC_OPTS=-buildtag ilx-O $(GHC_ILX_OPTS) -O 
WAY_ilx-O-mono_ILX2IL_OPTS=--mono 
WAY_ilx-O-mono_ILX=YES

ALL_WAYS+=ilx-Onot-generic-traced
WAY_ilx-Onot-generic-traced_NAME=ILX with Haskell Optimizer Off to run on Generic CLR
WAY_ilx-Onot-generic-traced_HC_OPTS=-buildtag ilx-Onot $(GHC_ILX_OPTS) -Onot 
WAY_ilx-Onot-generic-traced_ILX2IL_OPTS=--generic  --traced
WAY_ilx-Onot-generic-traced_ILX=YES

ALL_WAYS+=ilx-O-generic-traced
WAY_ilx-O-generic-traced_NAME=ILX with Haskell Optimizer On to run on Generic CLR
WAY_ilx-O-generic-traced_HC_OPTS=-buildtag ilx-O $(GHC_ILX_OPTS) -O 
WAY_ilx-O-generic-traced_ILX2IL_OPTS=--generic  --traced
WAY_ilx-O-generic-traced_ILX=YES

ALL_WAYS+=ilx-Onot-mono-traced
WAY_ilx-Onot-mono-traced_NAME=ILX with Haskell Optimizer Off to run on V1 CLR
WAY_ilx-Onot-mono-traced_HC_OPTS=-buildtag ilx-Onot $(GHC_ILX_OPTS) -Onot 
WAY_ilx-Onot-mono-traced_ILX2IL_OPTS=--mono  --traced
WAY_ilx-Onot-mono-traced_ILX=YES

ALL_WAYS+=ilx-O-mono-traced
WAY_ilx-O-mono-traced_NAME=ILX with Haskell Optimizer On to run on V1 CLR
WAY_ilx-O-mono-traced_HC_OPTS=-buildtag ilx-O $(GHC_ILX_OPTS) -O 
WAY_ilx-O-mono-traced_ILX2IL_OPTS=--mono  --traced
WAY_ilx-O-mono-traced_ILX=YES

# Put a "." after the Haskell portion of the way.  Way names can't contain
# dots for some reason elsewhere in the Make system.  But we need to be able
# to split out the Haskell portion of the way from the ILX portion (e.g. --generic)
# and the runtime portion (e.g. --retail).
ilx_way=$(subst ilx-Onot-,ilx-Onot.,$(subst ilx-O-,ilx-O.,$(way)))
ilx2il_suffix=$(subst ilx-Onot.,.,$(subst ilx-O.,.,$(ilx_way)))
hs2ilx_suffix=$(subst $(ilx2il_suffix),,$(ilx_way))
HS_ILX=$(subst $(way),$(hs2ilx_suffix),$(HS_OBJS))
HS_IL=$(subst $(hs2ilx_suffix)_o,$(ilx_way).il,$(HS_ILX))
HS_MODS=$(subst $(ilx_way).il,$(ilx_way).dll,$(HS_IL))

debug: 
	@echo ilx_way=$(ilx_way)
	@echo ""
	@echo HS_OBJS=$(HS_OBJS)
	@echo ""
	@echo HS_ILX=$(HS_ILX)
	@echo ""
	@echo HS_IL=$(HS_IL)
	@echo ""
	@echo HS_MODS=$(HS_MODS)
	@echo ""
	@echo ilx2il_suffix=$(ilx2il_suffix)
	@echo ""
	@echo hs2ilx_suffix=$(hs2ilx_suffix)

ILX2IL=//c/devel/fcom/src/bin/ilx2il.exe
ILVALID=//c/devel/fcom/src/bin/ilvalid.exe
ILVERIFY=//c/devel/fcom/src/bin/ilverify.exe

# We have new rules because only the Haskell-->ILX contribution to the whole "way"
# forms the "way" for the purposes of these rules
%.$(hs2ilx_suffix)_o : %.lhs	 
	$(HC_PRE_OPTS)
	$(HC) $(HC_OPTS) -osuf $(hs2ilx_suffix)_o -hisuf $(hs2ilx_suffix)_hi -c $< -o $*.$(hs2ilx_suffix)_o
	$(HC_POST_OPTS)

%.$(hs2ilx_suffix)_o : %.hs	 
	$(HC_PRE_OPTS)
	$(HC) $(HC_OPTS) -osuf $(hs2ilx_suffix)_o -hisuf $(hs2ilx_suffix)_hi -c $< -o $*.$(hs2ilx_suffix)_o
	$(HC_POST_OPTS)

%.$(hs2ilx_suffix)_hi : %.$(hs2ilx_suffix)_o
	@if [ ! -f $@ ] ; then \
	    echo Panic! $< exists, but $@ does not. \
	    exit 1; \
	else exit 0 ; \
	fi							

.PRECIOUS:  %.$(hs2ilx_suffix)_o %.$(hs2ilx_suffix)_hi %.$(ilx_way).il %.$(ilx_way).dll 

%.$(ilx_way).il : %.$(hs2ilx_suffix)_o  %.$(hs2ilx_suffix)_hi  $(ILX2IL)
	$(ILX2IL) --suffix  $(ilx2il_suffix) $(WAY_$(way)_ILX2IL_OPTS) -o $@ $*.$(hs2ilx_suffix)_o

%.$(ilx_way).dll : %.$(ilx_way).il	 
	echo "call devcorb2gen free" > tmp.bat
	echo "ilasm /DEBUG /QUIET /DLL /OUT=$@ $<" >> tmp.bat
	cmd /c tmp.bat

%.$(ilx_way).mvl : %.$(ilx_way).il $(HS_IL)  
	((ILVALID_HOME=c:\\devel\\fcom\\src\\ ILVALID_MSCORLIB=mscorlib.vlb $(ILVALID) c:\\devel\\fcom\\src\\bin\\msilxlib$(ilx2il_suffix).vlb  $(addprefix --other-il-module ,$(filter-out $*.$(ilx_way).il,$(HS_IL))) $<) 2>&1) | tee $@

%.$(ilx_way).mvr : %.$(ilx_way).il $(HS_IL) 
	((ILVALID_HOME=c:\\devel\\fcom\\src\\ ILVALID_MSCORLIB=mscorlib.vlb $(ILVERIFY) c:\\devel\\fcom\\src\\bin\\msilxlib$(ilx2il_suffix).vlb  $(addprefix --other-il-module ,$(filter-out $<,$(HS_IL))) $<) 2>&1) | tee $@

.PRECIOUS: %.$(ilx_way).il %.$(ilx_way).ilx  %.$(ilx_way).exe  %.$(ilx_way).dll
