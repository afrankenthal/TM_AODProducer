#! /bin/bash

## This script is used to generate AOD files from a particle gun off condor.
## The CMSSW version is 12_3_3.
##

## Usage: ./generateEvents.sh [your-eos-lpc-username]

#my_exit_function() {
#    exit $? # if on condor
#    return # if local 
#}

nevent=20 # 2000 for production, 20 for testing
USERNAME=$1
RELEASE="CMSSW_12_4_11_patch3"
export BASEDIR=`pwd`
SAMPLE="EtaToGammaTM_TMToEE"
BASENAME="${SAMPLE}_2022"
GENSIM_cfg="${BASENAME}_GENSIM_cfg.py"
DR_cfg="${BASENAME}_DIGIRAWHLT_cfg.py"
AOD_cfg="${BASENAME}_AOD_cfg.py"
MINIAOD_cfg="${BASENAME}_MINIAOD_cfg.py"

echo "Starting script for user: $USERNAME ..."
echo "Will save generated AODs at: /store/user/$USERNAME/$BASENAME/MINIAOD_Signal_Samples/"


export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
source $VO_CMS_SW_DIR/cmsset_default.sh

export SCRAM_ARCH=slc7_amd64_gcc10
if ! [ -r $RELEASE/src ] ; then
    scram p CMSSW $RELEASE
fi

#cp -r Configuration/ CMSSW_10_2_3/src
#cp -r GeneratorInterface/ CMSSW_10_2_3/src

cd $RELEASE/src
eval `scram runtime -sh`
#git cms-init
#git cms-merge-topic afrankenthal:pluto-reader-gun-run3
#git cms-merge-topic afrankenthal:pluto-reader-gun-run3-1202
#git cms-merge-topic bennettgberg:pluto-reader-gun-12_4_11_patch3
git cms-merge-topic afrankenthal:CSVReader-CMSSW_12_4_11_patch3
scram b -j 4 || exit $?;
cp ../../$DR_cfg .
ls -lrth


RANDOMSEED=`od -vAn -N4 -tu4 < /dev/urandom`
#Sometimes the RANDOMSEED is too long for madgraph
RANDOMSEED=`echo $RANDOMSEED | rev | cut -c 3- | rev`
#namebase="EtaTo2Mu2E_$RANDOMSEED"
#namebase="$sample_2022"

echo "Copying pluto events file."
#xrdcp root://cmseos.fnal.gov//store/user/bgreenbe/pluto_EtaTo2Mu2E_1M_events.csv GeneratorInterface/Pythia8Interface/test/
xrdcp root://cmseos.fnal.gov//store/user/asterenb/EtaToGammaTM_TMToEE_550ketas.csv GeneratorInterface/Pythia8Interface/test/EtaToGammaTM_TMToEE_550Ketas.csv

echo "1.) Generating GEN-SIM for $SAMPLE from CSV events"

#cmsDriver.py Configuration/Generator/python/PlutoReader_EtaTo2Mu2E_pythia8_cfi.py --python_filename $GENSIM_cfg --eventcontent RAWSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM --fileout file:${BASENAME}_GENSIM.root --conditions 124X_mcRun3_2022_realistic_postEE_v1 --beamspot Realistic25ns13p6TeVEarly2022Collision --customise_commands "process.g4SimHits.Physics.G4GeneralProcess = cms.bool(False)" --step GEN,SIM --geometry DB:Extended --era Run3 --no_exec --mc -n ${nevent} || exit:$?;
cmsDriver.py Configuration/Generator/python/CSVReader_pythia8_cfi.py --python_filename $GENSIM_cfg --eventcontent RAWSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM --fileout file:${BASENAME}_GENSIM.root --conditions 124X_mcRun3_2022_realistic_postEE_v1 --beamspot Realistic25ns13p6TeVEarly2022Collision --step GEN,SIM --geometry DB:Extended --era Run3 --no_exec --mc -n ${nevent} || exit:$?;

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
echo "2.) Generating DIGI-RAW-HLT for $SAMPLE"

sed -i "s/file:placeholder_in.root/file:${BASENAME}_GENSIM.root/g" $DR_cfg
sed -i "s/file:placeholder_out.root/file:${BASENAME}_DIGIRAWHLT.root/g" $DR_cfg
sed -i "s/input = cms.untracked.int32(10)/input = cms.untracked.int32(${nevent})/g" $DR_cfg

#mv $DR_cfg EtaTo2MuE_DIGIRAWHLT_cfg.py
cmsRun -p $DR_cfg #EtaTo2Mu2E_DIGIRAWHLT_cfg.py

# Then run HLT by hand to incorporate scouting collections
echo "3.) Running HLT for $SAMPLE"

cmsDriver.py step2 \
    --filein file:${BASENAME}_DIGIRAWHLT.root \
    --fileout file:${BASENAME}_AOD.root \
    --mc --eventcontent AODSIM --datatier AODSIM --runUnscheduled \
    --conditions 124X_mcRun3_2022_realistic_postEE_v1 --step RAW2DIGI,L1Reco,RECO,RECOSIM --procModifiers siPixelQualityRawToDigi \
    --nThreads 1 --era Run3 --python_filename $AOD_cfg --no_exec \
    --customise Configuration/DataProcessing/Utils.addMonitoring -n ${nevent} || exit $?;

cmsRun -p $AOD_cfg

echo "4.) Generating MINIAOD for $SAMPLE"

cmsDriver.py step3 \
       --filein file:${BASENAME}_AOD.root \
       --fileout file:${BASENAME}_MINIAOD.root \
       --mc --eventcontent MINIAODSIM --datatier MINIAODSIM --runUnscheduled \
       --conditions 124X_mcRun3_2022_realistic_postEE_v1 --step PAT \
       --nThreads 1 --era Run3 --python_filename $MINIAOD_cfg --no_exec \
       --customise Configuration/DataProcessing/Utils.addMonitoring -n ${nevent} || exit $?;

cmsRun -p $MINIAOD_cfg

pwd
cmd="ls -arlth *.root"
echo $cmd
eval $cmd

#for first submission, file arg is just the job number
arg=$2
#if resubmitting error files, arg is the missing ones
#errfiles=( 12 162 169 22 257 273 )
#arg=${errfiles[arg]}

# this assumes your EOS space on the LPC has the same name as your local username (or your DN is mapped to it)
# if not, change below line to actual EOS space name
#xrdcp ${namebase}_scoutingPF_2021.root root://cmseos.fnal.gov//store/user/$USERNAME/EtaTo2Mu2E/AOD_Signal_Samples/
#xrdcp -f ${namebase}_MINIAOD_2022.root root://cmseos.fnal.gov//store/user/$USERNAME/EtaTo2Mu2E/Run3_2022_MINIAOD/${namebase}_${2}_MINIAOD_2022.root
#sending new files to new directory
#xrdcp -f ${namebase}_MINIAOD_2022.root root://cmseos.fnal.gov//store/user/$USERNAME/EtaTo2Mu2E/Run3_2022_MINIAOD_2/${namebase}_${2}_MINIAOD_2022.root
#xrdcp -f ${namebase}_MINIAOD_2022.root root://cmseos.fnal.gov//store/user/$USERNAME/EtaTo2Mu2E/Run3_2022_MINIAOD_3/${namebase}_${2}_MINIAOD_2022.root
xrdcp -f ${BASENAME}_MINIAOD.root root://cmseos.fnal.gov//store/user/$USERNAME/$BASENAME/${BASENAME}_MINIAOD_${arg}.root

echo "Done!"
