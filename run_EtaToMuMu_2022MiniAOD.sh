#! /bin/bash

## This script is used to generate AOD files from a particle gun off condor.
## The CMSSW version is 10_2_3.
##
## Currently MINIAOD production is commented out to save time (and we don't use it).

## Usage: ./generateEvents.sh [your-eos-lpc-username]

#my_exit_function() {
#    exit $? # if on condor
#    return # if local 
#}

USERNAME=$1
export BASEDIR=`pwd`

echo "Starting script for user: $USERNAME ..."
#echo "Will save generated AODs at: /store/user/$USERNAME/EtaTo2Mu2E/AOD_Signal_Samples/"

#2000 events for real run!
nevent=2000
##20 events just for test!
#nevent=20
#release0='CMSSW_12_0_2'
release0='CMSSW_12_4_11_patch3'

export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
source $VO_CMS_SW_DIR/cmsset_default.sh

export SCRAM_ARCH=slc7_amd64_gcc10
if ! [ -r $release0/src ] ; then
    scram p CMSSW $release0
fi

#cp -r Configuration/ CMSSW_10_2_3/src
#cp -r GeneratorInterface/ CMSSW_10_2_3/src

cd $release0/src
eval `scram runtime -sh`
git cms-init
#git cms-merge-topic afrankenthal:pluto-reader-gun
#git cms-merge-topic bennettgberg:pluto-reader-gun
#git cms-merge-topic bennettgberg:pluto-reader-gun-12_0_2
git cms-merge-topic bennettgberg:pluto-reader-gun-12_4_11_patch3
scram b -j 4 || exit $?;
ls -lrth


#RANDOMSEED=`od -vAn -N4 -tu4 < /dev/urandom`
#Sometimes the RANDOMSEED is too long for madgraph
#RANDOMSEED=`echo $RANDOMSEED | rev | cut -c 3- | rev`

#jobnum=$2

namebase="EtaToMuMu_2022Test"
innum=$2
#relaunching error files!!!!
#errfiles=(170 171 206 240 249 257 307 322 350 378 383)
#errfiles=( 105 134 184 233 264 281 329 377 426 459 476 506 524 556 57 603 621 651 669 7 )
#errfiles=( 106 129 168 253 327 362 379 467 681 683 )
jobnum=$innum
#jobnum=${errfiles[innum]}
innum=$jobnum
#fnum=$(( innum + 1 ))

#randomseed=$(( innum * 123 + 5 ))
#second batch, use higher random seed
randomseed=$(( innum * 123 + 67890 ))
echo "randomseed: $randomseed"

echo "1.) Generating GEN-SIM `date`"
ls
cmsDriver.py Configuration/Generator/Py8Eta2MuPtGun_cfi.py --fileout file:${namebase}_GENSIM.root  --mc --eventcontent RAWSIM --datatier GEN-SIM --conditions 124X_mcRun3_2022_realistic_postEE_v1 --beamspot Realistic25ns13p6TeVEarly2022Collision --step GEN,SIM --geometry DB:Extended --era Run3 --nThreads 1 --customise Configuration/DataProcessing/Utils.addMonitoring  --python_filename ${namebase}_GS_cfg.py --no_exec -n $nevent

echo "process.RandomNumberGeneratorService.generator.initialSeed = cms.untracked.uint32(${randomseed})" >> ${namebase}_GS_cfg.py

#cmsRun -j FrameworkJobReport.xml -p ${namebase}_GSDR_cfg.py
cmsRun -p ${namebase}_GS_cfg.py

echo "2.) Generating DIGI-RAW-HLT for EtaToMuMu"
#cd ../..
#release1='CMSSW_12_4_11_patch3'
#if ! [ -r $release1/src ] ; then
#    scram p CMSSW $release1
#fi
#cd $release1/src
#eval `scram runtime -sh`

cp ../../${namebase}_DIGIRAWHLT_cfg.py .
#mv ../../$release0/src/${namebase}_GENSIM.root .

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
#    --python_filename ${namebase}_DIGIRAWHLT_cfg.py \ 
#    --customise Configuration/DataProcessing/Utils.addMonitoring \
#    --no_exec || exit $?;
##this line??
#    #--geometry DB:Extended --nThreads 1 \
#cmsDriver.py step1 --filein file:EtaToMuMuGamma_2022Test_GENSIM.root --fileout file:EtaToMuMuGamma_2022Test_DIGIRAWHLT.root --era Run3 --conditions 120X_mcRun3_2021_realistic_v6 --mc --step DIGI,DATAMIX,L1,DIGI2RAW,HLT:@relval2018 --procModifiers premix_stage2 --datamix PreMix --datatier GEN-SIM-DIGI-RAW --eventcontent PREMIXRAW --pileup_input dbs:/Neutrino_E-10_gun/Run3Summer21PrePremix-Summer22_124X_mcRun3_2022_realistic_v11-v2/PREMIX --number 1 --python_filename EtaToMuMuGamma_2022Test_DIGIRAWHLT_cfg.py --no_exec
cmsRun -p ${namebase}_DIGIRAWHLT_cfg.py

echo "3.) Generating AOD for EtaToMuMu"

#first copy the file
#xrdcp root://cmseos.fnal.gov//store/user/bgreenbe/EtaToMuMuGamma/CRAB_PrivateMC/crab_test100k_12/221216_151006/0000/${namebase}_GSDR_${fnum}.root inFile.root
#xrdcp root://cmseos.fnal.gov//store/user/bgreenbe/EtaToMuMuGamma/CRAB_PrivateMC/crab_test10M_0/221219_165628/0000/${namebase}_GSDR_${fnum}.root inFile.root

cmsDriver.py step2 \
    --filein file:${namebase}_DIGIRAWHLT.root \
    --fileout file:${namebase}_AOD_2022.root \
    --mc --eventcontent AODSIM --datatier AODSIM --runUnscheduled \
    --conditions 124X_mcRun3_2022_realistic_postEE_v1 --step RAW2DIGI,L1Reco,RECO,RECOSIM --procModifiers siPixelQualityRawToDigi \
    --nThreads 1 --era Run3 --python_filename EtaToMuMu_AOD_cfg.py --no_exec \
    --customise Configuration/DataProcessing/Utils.addMonitoring -n ${nevent} || exit $?;

cmsRun -p EtaToMuMu_AOD_cfg.py

## MINIAOD production is commented out
echo "4.) Generating MINIAOD"
cmsDriver.py step3 \
       --filein file:${namebase}_AOD_2022.root \
       --fileout file:${namebase}_MINIAOD_2022.root \
       --mc --eventcontent MINIAODSIM --datatier MINIAODSIM --runUnscheduled \
       --conditions 124X_mcRun3_2022_realistic_postEE_v1 --step PAT \
       --nThreads 1 --era Run3 --python_filename ${namebase}_MINIAOD_cfg.py --no_exec \
       --customise Configuration/DataProcessing/Utils.addMonitoring -n ${nevent} || exit $?;
cmsRun -p ${namebase}_MINIAOD_cfg.py

#echo "5.) Generating NANOAOD"
#cmsDriver.py step4 \
#       --filein file:${namebase}_MINIAOD_2018.root \
#       --fileout file:${namebase}_NANOAOD_2018.root \
#       --mc --eventcontent NANOAODSIM --datatier NANOAODSIM --runUnscheduled \
#       --conditions auto:phase1_2018_realistic --step NANO \
#       --nThreads 1 --era Run2_2018 --python_filename ${namebase}_NANOAOD_cfg.py --no_exec \
#       --customise Configuration/DataProcessing/Utils.addMonitoring -n ${nevent} || exit $?;
#cmsRun -p ${namebase}_NANOAOD_cfg.py

#
#pwd
#cmd="ls -arlth *.root"
#echo $cmd
#eval $cmd
#
## this assumes your EOS space on the LPC has the same name as your local username (or your DN is mapped to it)
## if not, change below line to actual EOS space name
#xrdcp -f ${namebase}_AOD_2018.root root://cmseos.fnal.gov//store/user/$USERNAME/EtaToMuMuGamma/AOD_Signal_Samples/
#xrdcp ${namebase}_MINIAOD_2022.root root://cmseos.fnal.gov//store/user/$USERNAME/EtaToMuMuGamma/Run3_2022_MINIAOD/${namebase}_MINIAOD_${jobnum}.root
#xrdcp -f ${namebase}_MINIAOD_2022.root root://cmseos.fnal.gov//store/user/$USERNAME/EtaToMuMu/Run3_2022_MINIAOD/${namebase}_MINIAOD_${jobnum}.root
#second batch--use new directory
xrdcp -f ${namebase}_MINIAOD_2022.root root://cmseos.fnal.gov//store/user/$USERNAME/EtaToMuMu/Run3_2022_MINIAOD_2/${namebase}_MINIAOD_${jobnum}.root
#xrdcp -f ${namebase}_NANOAOD_2018.root root://cmseos.fnal.gov//store/user/$USERNAME/EtaToMuMuGamma/NANOAOD_Signal_Samples/${namebase}_NANOAOD_${jobnum}.root

echo "Done!"
