#! /bin/bash

R -q -e "pak::pak('ravebuiltins')"
R -q -e "ravemanager::install(python = FALSE, finalize = FALSE)"
R -q -e "ravemanager::configure_python()"
R -q -e "pak::cache_clean(); ravemanager:::pak_cache_remove()"

# Remove
/opt/shared/rave/lib/conda/condabin/conda clean --all --yes
rm -rf /tmp/*
