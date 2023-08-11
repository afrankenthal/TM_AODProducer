#! /bin/bash

## This script is used to generate AOD files from a particle gun off condor.
## The CMSSW version is 12_3_3.
##
## Currently MINIAOD production is commented out to save time (and we don't use it).

## Usage: ./generateEvents.sh [your-eos-lpc-username]

#my_exit_function() {
#    exit $? # if on condor
#    return # if local 
#}

nevent=1000
#nevent=100
USERNAME=$1
export BASEDIR=`pwd`
release="CMSSW_12_0_2"
GENSIM_cfg="EtaTo2Mu2E_GENSIM_cfg.py"
DR_cfg="EtaTo2Mu2E_DIGIRAWHLT_template_2021_cfg.py"

echo "Starting script for user: $USERNAME ..."
echo "Will save generated AODs at: /store/user/$USERNAME/EtaTo2Mu2E/AOD_Signal_Samples/"


export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
source $VO_CMS_SW_DIR/cmsset_default.sh

export SCRAM_ARCH=slc7_amd64_gcc10
if ! [ -r $release/src ] ; then
    scram p CMSSW $release
fi

#cp -r Configuration/ CMSSW_10_2_3/src
#cp -r GeneratorInterface/ CMSSW_10_2_3/src

cd $release/src
eval `scram runtime -sh`
#git cms-init
#git cms-merge-topic afrankenthal:pluto-reader-gun-run3
git cms-merge-topic afrankenthal:pluto-reader-gun-run3-1202
scram b -j 4 || exit $?;
cp ../../$DR_cfg .
ls -lrth


RANDOMSEED=`od -vAn -N4 -tu4 < /dev/urandom`
#Sometimes the RANDOMSEED is too long for madgraph
RANDOMSEED=`echo $RANDOMSEED | rev | cut -c 3- | rev`
namebase="EtaTo2Mu2E_$RANDOMSEED"


echo "1.) Generating GEN-SIM for EtaTo2Mu2E from pluto events"

cmsDriver.py Configuration/Generator/python/PlutoReader_EtaTo2Mu2E_pythia8_cfi.py --python_filename $GENSIM_cfg --eventcontent RAWSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM --fileout file:${namebase}_GENSIM.root --conditions 120X_mcRun3_2021_realistic_v6 --beamspot Run3RoundOptics25ns13TeVLowSigmaZ --customise_commands "process.g4SimHits.Physics.G4GeneralProcess = cms.bool(False)" --step GEN,SIM --geometry DB:Extended --era Run3 --no_exec --mc -n ${nevent} || exit:$?;

# Make each file unique to make later publication possible
# (by making lumi section equal to the random seed)
# Also add random seed to Random Number Generator Service
linenumber=`grep -n 'process.source' $GENSIM_cfg | awk '{print $1}'`
linenumber=${linenumber%:*}
total_linenumber=`cat $GENSIM_cfg | wc -l`
bottom_linenumber=$(( $total_linenumber - $linenumber ))
tail -n $bottom_linenumber $GENSIM_cfg > tail.py
head -n $linenumber $GENSIM_cfg > head.py
echo "process.source.firstRun = cms.untracked.uint32(1)" >> head.py
echo "process.source.firstLuminosityBlock = cms.untracked.uint32($RANDOMSEED)" >> head.py
echo "process.RandomNumberGeneratorService.generator.initialSeed = $RANDOMSEED" >> head.py
cat tail.py >> head.py
mv head.py $GENSIM_cfg
rm -rf tail.py

cmsRun -p $GENSIM_cfg

# Step1 is pre-computed, since it takes a while to load all pileup pre-mixed samples
# So just replace template with correct filenames and number of events
echo "2.) Generating DIGI-RAW-HLT for EtaTo2Mu2E"

sed -i "s/file:placeholder_in.root/file:${namebase}_GENSIM.root/g" $DR_cfg
sed -i "s/file:placeholder_out.root/file:${namebase}_DIGIRAWHLT.root/g" $DR_cfg
sed -i "s/input = cms.untracked.int32(10)/input = cms.untracked.int32(${nevent})/g" $DR_cfg

#mv $DR_cfg EtaTo2MuE_DIGIRAWHLT_cfg.py
cmsRun -p $DR_cfg #EtaTo2Mu2E_DIGIRAWHLT_cfg.py

## Then run HLT by hand to incorporate scouting collections
#echo "3.) Running HLT for EtaTo2Mu2E"
#
#cd ../..
#if ! [ -r CMSSW_12_3_3/src ] ; then
#    scram p CMSSW CMSSW_12_3_3
#fi
#
#cd CMSSW_12_3_3/src
#eval `scram runtime -sh`
##git cms-init
##git cms-merge-topic afrankenthal:pluto-reader-gun-run3
#scram b -j 4 || exit $?;
#cp ../../scoutingPF_2021.py .
#ls -lrth
#
##hltGetConfiguration /dev/CMSSW_12_3_0/GRun --globaltag auto:phase1_2021_realistic --full --mc --type GRun --eras Run3 --process HLTX --unprescale --no-output --input file:../../CMSSW_12_0_2/src/${namebase}_DIGIRAWHLT.root --max-events -1 --l1-emulator FullMC --customise HLTrigger/Configuration/customizeHLTforPatatrack.customizeHLTforPatatrackTriplets --l1 L1Menu_Collisions2022_v1_0_1_xml --paths HLTriggerFirstPath,DST_Run3_PFScoutingPixelTracking_v16,Dataset_ScoutingPFRun3,ScoutingPFOutput > scoutingPF.py
#
#sed -i "s|file:placeholder_in.root|file:../../${release}/src/${namebase}_DIGIRAWHLT.root|g" scoutingPF_2021.py

#cmsRun -p scoutingPF_2021.py
#mv outputScoutingPF.root ${namebase}_scoutingPF_2021.root

#echo "2.) Generating DIGI-RAW-HLT for EtaTo2Mu2E"
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
#    --python_filename EtaTo2Mu2E_DIGIRAWHLT_cfg.py \ 
#    --customise Configuration/DataProcessing/Utils.addMonitoring \
#    --no_exec || exit $?;

#echo "3.) Generating AOD for EtaTo2Mu2E"
#
#cmsDriver.py step2 \
#    --filein file:${namebase}_DIGIRAWHLT.root \
#    --fileout file:${namebase}_AOD_2018.root \
#    --mc --eventcontent AODSIM --datatier AODSIM --runUnscheduled \
#    --conditions 102X_upgrade2018_realistic_v15 --step RAW2DIGI,L1Reco,RECO,RECOSIM,EI \
#    --procModifiers premix_stage2 \
#    --nThreads 1 --era Run2_2018 --python_filename EtaTo2Mu2E_AOD_cfg.py --no_exec \
#    --customise Configuration/DataProcessing/Utils.addMonitoring -n ${nevent} || exit $?;
#
#cmsRun -p EtaTo2Mu2E_AOD_cfg.py

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
#xrdcp ${namebase}_scoutingPF_2021.root root://cmseos.fnal.gov//store/user/$USERNAME/EtaTo2Mu2E/AOD_Signal_Samples/
xrdcp ${namebase}_DIGIRAWHLT.root root://cmseos.fnal.gov//store/user/$USERNAME/EtaTo2Mu2E/GSDR_Run3_Signal_Samples/

echo "Done!"
