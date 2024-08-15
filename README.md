# RFdiffusion Pipeline (Graham cluster)

Please see [https://github.com/Brett-Trost-Lab/rfdiffusion-pipeline](https://github.com/Brett-Trost-Lab/rfdiffusion-pipeline) for the main repository.

# Installation

These instructions install the programs as virtual environments rather than conda environments. Thanks Nemo Liu for figuring this out!
```
INSTALLATION_DIR=/path/to/dir/for/installations/  # ideally in your 'projects/' folder, where you have a lot of space
cd $INSTALLATION_DIR
```

### RFdiffusion
```
# clone repo
module load StdEnv/2020 gcc python/3.10
git clone https://github.com/RosettaCommons/RFdiffusion

# download model weights
cd RFdiffusion/
mkdir models && cd models
wget http://files.ipd.uw.edu/pub/RFdiffusion/6f5902ac237024bdd0c176cb93063dc4/Base_ckpt.pt
wget http://files.ipd.uw.edu/pub/RFdiffusion/e29311f6f1bf1af907f9ef9f44b8328b/Complex_base_ckpt.pt
wget http://files.ipd.uw.edu/pub/RFdiffusion/60f09a193fb5e5ccdc4980417708dbab/Complex_Fold_base_ckpt.pt
wget http://files.ipd.uw.edu/pub/RFdiffusion/74f51cfb8b440f50d70878e05361d8f0/InpaintSeq_ckpt.pt
wget http://files.ipd.uw.edu/pub/RFdiffusion/76d00716416567174cdb7ca96e208296/InpaintSeq_Fold_ckpt.pt
wget http://files.ipd.uw.edu/pub/RFdiffusion/5532d2e1f3a4738decd58b19d633b3c3/ActiveSite_ckpt.pt
wget http://files.ipd.uw.edu/pub/RFdiffusion/12fc204edeae5b57713c5ad7dcb97d39/Base_epoch8_ckpt.pt
wget http://files.ipd.uw.edu/pub/RFdiffusion/f572d396fae9206628714fb2ce00f72e/Complex_beta_ckpt.pt
wget http://files.ipd.uw.edu/pub/RFdiffusion/1befcb9b28e2f778f53d47f18b7597fa/RF_structure_prediction_weights.pt

# make virtual environment
cd ..
virtualenv venv
source venv/bin/activate

# install packages
cd env/SE3Transformer
pip install --no-cache-dir -r requirements.txt
python setup.py install
cd ../..
pip install torch dgl hydra-core omegaconf pyrsistent pandas
python setup.py install

# move some directories

```

### ProteinMPNN and AlphaFold2 (dl_binder_design)
```
cd $INSTALLATION_DIR

# clone repo
module load StdEnv/2020 gcc/9.3.0 openmpi/4.0.3 python/3.10 cuda/11.7 cudnn/8.7.0 tensorrt/8.6.1.6
git clone https://github.com/nrbennet/dl_binder_design

# make virtual environment
cd dl_binder_design/
virtualenv venv
source venv/bin/activate
pip install --no-index --upgrade pip

# download pyrosetta
wget https://graylab.jhu.edu/download/PyRosetta4/archive/release/PyRosetta4.Release.python310.ubuntu.wheel/pyrosetta-2024.15+release.d972b59c53-cp310-cp310-linux_x86_64.whl

# install packages
pip install --no-index pyrosetta-2024.15+release.d972b59c53-cp310-cp310-linux_x86_64.whl torch biopython==1.81 ml-collections tensorflow==2.9 jax==0.4.8 jaxlib==0.4.7+cuda11.cudnn82.computecanada dm-haiku dm-tree mock

# clone ProteinMPNN

# download model weights

```

IN PROGRESS.
