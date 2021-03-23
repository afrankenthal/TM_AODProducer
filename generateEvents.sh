#! /bin/bash

## This script is used to generate AOD files from a particle gun off condor.
## The CMSSW version is 10_2_3.
##
## Currently MINIAOD production is commented out to save time (and we don't use it).

## Usage: ./generateEvents.sh

USERNAME=$1
export BASEDIR=`pwd`

echo "Starting script for user $USERNAME."
echo "Will save generated AODs at: /store/user/$USERNAME/TrueMuonium/AOD_Signal_Samples/"

nevent=1000

export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
source $VO_CMS_SW_DIR/cmsset_default.sh

export SCRAM_ARCH=slc7_amd64_gcc700
if ! [ -r CMSSW_10_2_3/src ] ; then
    scram p CMSSW CMSSW_10_2_3
fi

#cp -r Configuration/ CMSSW_10_2_3/src
#cp -r GeneratorInterface/ CMSSW_10_2_3/src

cd CMSSW_10_2_3/src
eval `scram runtime -sh`
git cms-init
git cms-merge-topic afrankenthal:displaced-pythia8-gun-correct
scram b -j 4 || exit $?;
ls -lrth

cp ../../TM_DIGIRAWHLT_template_2018_cfg.py .

RANDOMSEED=`od -vAn -N4 -tu4 < /dev/urandom`
#Sometimes the RANDOMSEED is too long for madgraph
RANDOMSEED=`echo $RANDOMSEED | rev | cut -c 3- | rev`

namebase="TM_$RANDOMSEED"

echo "1.) Generating GEN-SIM for True Muonium"

# Use TrueMuoniumFlatPtEtaPhiVxy_cfi.py for flat gun instead of Pythia8-based
cmsDriver.py TrueMuonium_DisplacedGun_pythia8_cfi.py \
    --fileout file:${namebase}_GENSIM.root \
    --mc --eventcontent RAWSIM --datatier GEN-SIM \
    --conditions 102X_upgrade2018_realistic_v15 --beamspot Realistic25ns13TeVEarly2018Collision \
    --step GEN,SIM --era Run2_2018 --nThreads 1 \
    --customise Configuration/DataProcessing/Utils.addMonitoring \
    --python_filename TM_GENSIM_cfg.py --no_exec -n ${nevent} || exit $?;

# Make each file unique to make later publication possible
# (by making lumi section equal to the random seed)
linenumber=`grep -n 'process.source' TM_GENSIM_cfg.py | awk '{print $1}'`
linenumber=${linenumber%:*}
total_linenumber=`cat TM_GENSIM_cfg.py | wc -l`
bottom_linenumber=$(( $total_linenumber - $linenumber ))
tail -n $bottom_linenumber TM_GENSIM_cfg.py > tail.py
head -n $linenumber TM_GENSIM_cfg.py > head.py
echo "process.source.firstRun = cms.untracked.uint32(1)" >> head.py
echo "process.source.firstLuminosityBlock = cms.untracked.uint32($RANDOMSEED)" >> head.py
cat tail.py >> head.py
mv head.py TM_GENSIM_cfg.py
rm -rf tail.py

cmsRun -p TM_GENSIM_cfg.py

# Step1 is pre-computed, since it takes a while to load all pileup pre-mixed samples
# So just replace template with correct filenames and number of events
echo "2.) Generating DIGI-RAW-HLT for True Muonium"

sed -i "s/file:placeholder_in.root/file:${namebase}_GENSIM.root/g" TM_DIGIRAWHLT_template_2018_cfg.py
sed -i "s/file:placeholder_out.root/file:${namebase}_DIGIRAWHLT.root/g" TM_DIGIRAWHLT_template_2018_cfg.py
sed -i "s/input = cms.untracked.int32(10)/input = cms.untracked.int32(${nevent})/g" TM_DIGIRAWHLT_template_2018_cfg.py
mv TM_DIGIRAWHLT_template_2018_cfg.py TM_DIGIRAWHLT_cfg.py

#echo "2.) Generating DIGI-RAW-HLT for True Muonium"
#
#cmsDriver.py step1 \
#    --filein file:${namebase}_GENSIM.root \
#    --fileout file:${namebase}_DIGIRAWHLT.root \
#    --era Run2_2018 --conditions 102X_upgrade2018_realistic_v15 \
#    --mc --step DIGI,DATAMIX,L1,DIGI2RAW,HLT:@relval2018 \
#    --procModifiers premix_stage2 \
#    --datamix PreMix \
#    --datatier GEN-SIM-DIGI-RAW --eventcontent PREMIXRAW \
#    --pileup_input "dbs:/Neutrino_E-10_gun/RunIISummer17PrePremix-PUAutumn18_102X_upgrade2018_realistic_v15-v1/GEN-SIM-DIGI-RAW" \
#    --number ${nevent} \
#    --geometry DB:Extended --nThreads 1 \
#    --python_filename TM_DIGIRAWHLT_cfg.py \ 
#    --customise Configuration/DataProcessing/Utils.addMonitoring \
#    --no_exec || exit $?;

cmsRun -p TM_DIGIRAWHLT_cfg.py

echo "3.) Generating AOD for True Muonium"

cmsDriver.py step2 \
    --filein file:${namebase}_DIGIRAWHLT.root \
    --fileout file:${namebase}_AOD_2018.root \
    --mc --eventcontent AODSIM --datatier AODSIM --runUnscheduled \
    --conditions 102X_upgrade2018_realistic_v15 --step RAW2DIGI,L1Reco,RECO,RECOSIM,EI \
    --procModifiers premix_stage2 \
    --nThreads 1 --era Run2_2018 --python_filename TM_AOD_cfg.py --no_exec \
    --customise Configuration/DataProcessing/Utils.addMonitoring -n ${nevent} || exit $?;

cmsRun -p TM_AOD_cfg.py

    # MINIAOD production is commented out
    #echo "4.) Generating MINIAOD"
    #cmsDriver.py step3 \
        #    --filein file:${namebase}_AOD.root \
        #    --fileout file:${namebase}_MINIAOD.root \
        #    --mc --eventcontent MINIAODSIM --datatier MINIAODSIM --runUnscheduled \
        #    --conditions auto:phase1_2018_realistic --step PAT \
        #    --nThreads 8 --era Run2_2018 --python_filename ${namebase}_MINIAOD_cfg.py --no_exec \
        #    --customise Configuration/DataProcessing/Utils.addMonitoring -n ${nevent} || exit $?;
    #cmsRun -p ${namebase}_MINIAOD_cfg.py

pwd
cmd="ls -arlth *.root"
echo $cmd
eval $cmd

# this assumes your EOS space on the LPC has the same name as your local username (or your DN is mapped to it)
# if not, change below line to actual EOS space name
xrdcp ${namebase}_AOD_2018.root root://cmseos.fnal.gov//store/user/$USERNAME/TrueMuonium/AOD_Signal_Samples/

echo "Done!"
