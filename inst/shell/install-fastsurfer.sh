#!/usr/bin/env bash
cd '/Users/dipterix/Dropbox (Personal)/projects/ravemanager'
if [ -f "/Users/dipterix/Library/r-rpymat/miniconda/etc/profile.d/conda.sh" ]; then
  . "/Users/dipterix/Library/r-rpymat/miniconda/etc/profile.d/conda.sh"
else
  export PATH="/Users/dipterix/Library/r-rpymat/miniconda/bin:$PATH"
fi

conda activate "/Users/dipterix/Library/r-rpymat/miniconda/envs/fastsurfer"
cd '/Users/dipterix/PennNeurosurgery Dropbox/Dipterix W/PennEMU_MRI/PAV076_20260122/nifti'

git clone https://github.com/Deep-MI/FastSurfer.git
cd FastSurfer
pip install --upgrade pip
pip install -r requirements.txt
# For M1/M2/M3 Macs
pip install torch torchvision torchaudio

# For Intel Macs
# pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
python FastSurferCNN/download_checkpoints.py

./run_fastsurfer.sh \
--t1 /path/to/input.nii.gz \
--sid subject_id \
--sd /path/to/output/directory \
--fs_license /path/to/freesurfer/license.txt

rpymat::run_command('', dry_run = T
                    )
