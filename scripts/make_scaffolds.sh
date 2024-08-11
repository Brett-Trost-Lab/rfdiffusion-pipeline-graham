#!/bin/bash
# Make secondary structure and block adjacency pytorch files from a PDB.
# Used for RFdiffusion fold conditioning.

### REQUIRED POSITIONAL ARGUMENTS
input=$(realpath $1)  # can be PDB or directory of PDBs to scaffold
output_dir=$(realpath $2)
##############################

set -eo pipefail

RFDIFFUSION_DIR=$HOME/projects/def-brt381/sxie1/RFdiffusion/

echo Loading modules...
module load StdEnv/2020 gcc python/3.10

echo Activating virtual environment...
source $RFDIFFUSION_DIR/venv/bin/activate

# check if input is a directory or single file

if [[ -d $input ]]; then
    echo $input is a directory.
    echo Running script...

    $RFDIFFUSION_DIR/helper_scripts/make_secstruc_adj.py \
        --pdb_dir $input \
        --out_dir $output_dir    

elif [[ -f $input ]]; then
    echo $input is a file.

    $RFDIFFUSION_DIR/helper_scripts/make_secstruc_adj.py \
        --input_pdb $input \
        --out_dir $output_dir
else
    echo $input is not a valid input.
    exit 1
fi

echo Done.
