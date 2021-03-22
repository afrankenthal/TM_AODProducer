# TM_AODProducer
Scripts to generate True Muonium MC simulation events with condor.

Default number of jobs (each job = 1k events) is 10. Can be adjusted in the last line of `condor_job.sub`.

Default output folder on EOS is `/store/user/$USER/TrueMuonium/AOD_Signal_Samples`, where $USER is your LPC username. If that is different from your CERN DN, you might need to change it if the two are not mapped.

Also make sure that the path `TrueMuonium/AOD_Signal_Samples` exists before running the production, using e.g. `eosmkdir /store/user/$USER/TrueMuonium/AOD_Signal_Samples`.
