# TM_AODProducer
Scripts to generate True Muonium MC simulation events with condor.

# Quick setup

Clone the repository on the LPC and change directories:

```bash
$ git clone https://github.com/afrankenthal/TM_AODProducer.git
$ cd TM_AODProducer
```

Now just create a proxy and run the condor job:

```bash
$ voms-proxy-init --voms cms --valid 192:00
$ condor_submit condor_job.sub
```

Default number of jobs (each job = 1k events) is 25. Can be adjusted in the last line of `condor_job.sub`.

Default output folder on EOS is `/store/user/[user]/TrueMuonium/AOD_Signal_Samples`, where `[user]` is your LPC username. If that is different from your CERN DN, you might need to change it if the two are not mapped.

Also make sure that the path `TrueMuonium/AOD_Signal_Samples` exists before running the production, using e.g. `eosmkdir /store/user/[user]/TrueMuonium/AOD_Signal_Samples`.

## Merging output files

The output AOD files are in CMS's Event Data Model (EDM) format, which prevents them from being hadd-ed together. Instead, use the `mergeAODs.py` CMS config provided here to merge all output files. Commands:

```bash
$ xrdfsls -u /store/user/[user]/TrueMuonium/AOD_Signal_Samples | grep .root > filelist.txt
$ mkdir -p /uscmst1b_scratch/lpc1/3DayLifetime/[user]
$ cmsRun mergeAODs.py outputFile=/uscmst1b_scratch/lpc1/3DayLifetime/[user]/merged.root inputFiles_load=filelist.txt
```

This creates a file named `merged.root` in the LPC's scratch space, so that it can be transferred to a permanent location (the merged file can be quite large so it might not fit in your personal LPC folder).
