## Dockerfiles for RAVE

For users who have trouble installing RAVE, we offer docker image builds. The image automatically rebuilds every Saturday (UTC).

### Get Started

If docker has not been installed, please download docker from https://www.docker.com/get-started/

Download [docker-compose.yml](docker-compose.yml), or save the following text in YAML file.

```yml
services:
  rave:
    image: ghcr.io/dipterix/ravemanager:main
    container_name: rave
    ports:
      - "127.0.0.1:2222:22"      # You can ssh to the container
      - "127.0.0.1:8788:8788"    # For RAVE application
    volumes:
      # /Folder/to/your/rave_data:/opt/shared/rave/data
      # do NOT change the path after ":"
      - $HOME/rave_data:/opt/shared/rave/data
    tty: false
    stdin_open: false
    restart: unless-stopped
```

Open terminal, `cd` to the folder where `docker-compose.yml` is stored, and run

```sh
docker compose up
```

### Customization

You may customize the `docker-compose.yml` file based on your settings. Here is a list of line-by-line explanations:

* The docker image is stored and tagged as `ghcr.io/dipterix/ravemanager:main`.
* The container name is `rave`.
* Port forwarding `127.0.0.1:2222:22` allows you to `ssh -p 2222 raveuser@localhost` once the container is up. The goal is to allow users to connect to the container and run code from within (YAEL preprocessing pipelines might need this), or edit via `vscode`. Change `2222` to another port if occupied, or delete this line if no SSH is needed.
* Localhost address `127.0.0.1:8788` is for RAVE web server. By default RAVE will launch at `http://127.0.0.1:8788`. Only the host machine may access the service.
* `$HOME/rave_data:/opt/shared/rave/data` mounts the RAVE data located at your home directory to the RAVE data repository inside of the container. If the RAVE data is stored at some other places, replace `$HOME/rave_data` with that path. For paths containing spaces, please make sure the path is properly quoted (e.g. `"/Volumes/My SSD/RAVE/rave_data":/opt/shared/rave/data`). Do NOT change the path after `:`.

### Update

```sh
# cd to docker-compose.yml

docker compose pull ghcr.io/dipterix/ravemanager:main
docker compose up -d
```

### Limitations & Workaround

The docker image does not contain 3rd-party tools such as AFNI, FreeSurfer, FSL. 
Therefore some pipelines such as YAEL image preprocess (`recon-all`) or 
co-registration via FSL or AFNI will fail. Please run the corresponding 
pipelines manually and copy over the files.

#### FreeSurfer

RAVE might run FreeSurfer recon-all (if user chooses so) command to generate surface models. Users can instead run by themselves and copy the results to the imaging folder.

To migrate FreeSurfer `recon-all` results, please find the subject folder (containing `mri`, `surf`, `label`, etc.) into the raw directory, under the subject imaging folder. For example `~/rave_data/raw_dir/yael_demo_001/rave-imaging` and rename the folder to `fs` (for FreeSurfer)

Here is an example directory tree:

```
~/rave_data/raw_dir/yael_demo_001/rave-imaging/
  fs/
    mri/
    surf/
    label/
    ...
```

#### FSL (coregistration)

If the user chooses to run FSL for coregistration, please align CT to MRI and make sure the transform matrix is exported. RAVE will use that matrix file to visualize the **original** CT (not the resampled) with MRI.

To migrate the FSL coregistration results, create a `coregistration` folder under the subject imaging path, and copy-paste the original MRI.nii.gz, CT.nii.gz, and transform matrix (e.g. `postToPre.mat`) into the coregistration.

Here is an example directory tree:

```
~/rave_data/raw_dir/yael_demo_001/rave-imaging/
  coregistration/
    MRI_RAW.nii.gz
    CT_RAW.nii.gz
    postToPre.mat
```
