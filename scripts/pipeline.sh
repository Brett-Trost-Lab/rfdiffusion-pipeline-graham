#!/bin/bash

# Runs the pipeline from RFDiffusion -> ProteinMPNN -> AlphaFold2.

############ UPDATE WITH YOUR INSTALLATION LOCATIONS ##############
RFDIFFUSION_DIR=/project/6090124/sxie1/repos/RFdiffusion/
DL_BINDER_DESIGN_DIR=/project/6090124/sxie1/repos/dl_binder_design/
###################################################################

set -eo pipefail

convert_seconds() {
    printf '%02dh:%02dm:%02ds\n' $((${1}/3600)) $((${1}%3600/60)) $((${1}%60))
}

# Measure computation time
SECONDS=0
total_seconds=0

pipeline_dir=$1
run_name=$2
path_to_pdb=$3
hotspots=$4
min_length=$5
max_length=$6
num_structs=$7
seq_per_struct=$8
min_helices=$9
output_dir="${10}/${run_name}/"
scaffold_dir="${11}"

echo PIPELINE_DIR $pipeline_dir
echo RUN_NAME $run_name
echo PDB_PATH $path_to_pdb
echo HOTSPOTS $hotspots
echo MIN_LENGTH $min_length
echo MAX_LENGTH $max_length
echo NUM_STRUCTS $num_structs
echo SEQ_PER_STRUCT $seq_per_struct
echo MIN_HELICES $min_helices
echo OUTPUT_DIR $output_dir
echo SCAFFOLD_DIR $scaffold_dir

echo
echo STEP 0: Data Preparation

echo
echo Using hotspots $hotspots

echo
echo Getting Contig...

echo Loading module...
module load StdEnv/2020 gcc python/3.10

echo Activating virtual environment...
source $RFDIFFUSION_DIR/venv/bin/activate

contig=$(python ${pipeline_dir}/scripts/get_contig.py "$path_to_pdb")
echo Contig $contig

echo
echo Data prep time elapsed: $(convert_seconds $SECONDS)
total_seconds=$((total_seconds+SECONDS))
SECONDS=0

echo
echo STEP 1: RFDiffusion

echo Running RFdiffusion...

if [ "$scaffold_dir" = "None" ]; then
    echo No fold conditioning.
    echo

    $RFDIFFUSION_DIR/scripts/run_inference.py \
        inference.input_pdb=$path_to_pdb \
	"contigmap.contigs=[$contig $min_length-$max_length]" \
	"ppi.hotspot_res=[$hotspots]" \
	inference.num_designs=$num_structs \
	inference.output_prefix=$output_dir/rfdiffusion/$run_name \
	denoiser.noise_scale_ca=0 \
	denoiser.noise_scale_frame=0
    
else
    echo Generating target scaffolds for fold conditioning...
    $RFDIFFUSION_DIR/helper_scripts/make_secstruc_adj.py \
        --input_pdb $path_to_pdb \
        --out_dir "${output_dir}/target_scaffold/"

    pdb_name=$(basename -- "$path_to_pdb")
    pdb_name="${pdb_name%.*}"
    echo
    echo pdb_name $pdb_name

    target_ss=${output_dir}/target_scaffold/${pdb_name}_ss.pt
    target_adj=${output_dir}/target_scaffold/${pdb_name}_adj.pt
    echo target_ss $target_ss
    echo target_adj $target_adj
    echo

    $RFDIFFUSION_DIR/scripts/run_inference.py \
        scaffoldguided.target_path=$path_to_pdb \
	scaffoldguided.scaffoldguided=True \
	"ppi.hotspot_res=[$hotspots]" \
	scaffoldguided.target_pdb=True \
	scaffoldguided.target_ss=$target_ss \
	scaffoldguided.target_adj=$target_adj \
	scaffoldguided.scaffold_dir=$scaffold_dir \
	inference.num_designs=$num_structs \
	inference.output_prefix=$output_dir/rfdiffusion/$run_name \
	denoiser.noise_scale_ca=0 \
	denoiser.noise_scale_frame=0 \
	scaffoldguided.mask_loops=False

fi


echo
echo RFDiffusion time elapsed: $(convert_seconds $SECONDS)
total_seconds=$((total_seconds+SECONDS))
SECONDS=0

echo
echo Filtering by number of helices...

if [ "$min_helices" -gt 1 ]; then

    echo
    echo Isolating binders from their PDB complexes...
    python $pipeline_dir/scripts/isolate_binders.py $output_dir/rfdiffusion/ $output_dir/rfdiffusion/binders_only/

    echo
    echo Making binder secondary structures...
    python $pipeline_dir/scripts/make_secstruc.py \
        --pdb_dir $output_dir/rfdiffusion/binders_only/ \
	--out_dir $output_dir/rfdiffusion/binders_only/sec_structs/

    mkdir -p $output_dir/rfdiffusion/below_threshold/
    
    for design in $output_dir/rfdiffusion/*.pdb; do
        design_name=$(basename "${design%.pdb}")

        echo
        echo Design $design_name

        binder_pdb=$output_dir/rfdiffusion/binders_only/${design_name}_binder.pdb
        ss_file=$output_dir/rfdiffusion/binders_only/sec_structs/${design_name}_binder_ss.pt
    
        if [ -f $ss_file ] && [ -f $binder_pdb ]; then
	    echo Sec struct file $ss_file
 	    num_helices=$(python $pipeline_dir/scripts/count_helices.py $ss_file)
	    echo Number of helices: $num_helices

	    if [ "$num_helices" -lt "$min_helices" ]; then
	        echo Does not pass threshold. Moving design to $output_dir/rfdiffusion/below_threshold/
	        mv $output_dir/rfdiffusion/$design_name.* $binder_pdb $output_dir/rfdiffusion/below_threshold/
	    fi

        else
	    echo Sec struct file does not exist.
        fi
    done

else
    echo No filtering.
fi

deactivate
module unload StdEnv/2020 gcc python/3.10

echo Loading module...
module load StdEnv/2020 gcc/9.3.0 openmpi/4.0.3 python/3.10 cuda/11.7 cudnn/8.7.0 tensorrt/8.6.1.6

echo Activating virtual environment...
source $DL_BINDER_DESIGN_DIR/venv/bin/activate

echo
echo STEP 2: ProteinMPNN

echo Running ProteinMPNN...

$DL_BINDER_DESIGN_DIR/mpnn_fr/dl_interface_design.py \
    -pdbdir $output_dir/rfdiffusion/ \
    -outpdbdir $output_dir/proteinmpnn/ \
    -relax_cycles 0 \
    -seqs_per_struct $seq_per_struct \
    -checkpoint_name ${output_dir}/${run_name}.check.point \
    -temperature 0.0001  # as specified in Watson et al. supplementary methods

echo
echo ProteinMPNN time elapsed: $(convert_seconds $SECONDS)
total_seconds=$((total_seconds+SECONDS))
SECONDS=0

echo
echo STEP 3: AlphaFold2

echo Activating conda...

echo Running AF2...
$DL_BINDER_DESIGN_DIR/af2_initial_guess/predict.py \
    -pdbdir $output_dir/proteinmpnn/ \
    -outpdbdir $output_dir/af2/ \
    -checkpoint_name ${output_dir}/${run_name}.check.point \
    -scorefilename ${output_dir}/${run_name}.out.sc

deactivate
module unload StdEnv/2020 gcc/9.3.0 openmpi/4.0.3 python/3.10 cuda/11.7 cudnn/8.7.0 tensorrt/8.6.1.6

echo Loading module...
module load StdEnv/2020 gcc python/3.10

echo Activating virtual environment...
source $RFDIFFUSION_DIR/venv/bin/activate

echo
echo Filtering output scores...
python $pipeline_dir/scripts/filter_output.py ${output_dir}/${run_name}.out.sc

echo
echo AF2 time elapsed: $(convert_seconds $SECONDS)
total_seconds=$((total_seconds+SECONDS))
echo Total time elapsed: $(convert_seconds $total_seconds)

echo
echo Done pipeline.

