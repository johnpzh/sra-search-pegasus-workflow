# SRA Search Workflow Slurm Version

# Prerequisite

Tested using
* Python 3.11.0
* GCC 11.2.0
* CMake 3.30.5

## Install Bowtie2 (for `bowtie2`, `bowtie2-build`)
Links:
1. https://bowtie-bio.sourceforge.net/bowtie2/index.shtml
2. https://github.com/BenLangmead/bowtie2

Commands:
```bash
curl -OL https://github.com/BenLangmead/bowtie2/releases/download/v2.5.4/bowtie2-2.5.4-linux-x86_64.zip
unzip bowtie2-2.5.4-linux-x86_64.zip
# Then make copy or make symlinks to $PATH
```

## Install Samtools (for `samtools`)
Links:
1. https://www.htslib.org/

Commands:
```bash
curl -OL https://github.com/samtools/samtools/releases/download/1.22.1/samtools-1.22.1.tar.bz2
tar xvf samtools-1.22.1.tar.bz2
cd samtools-1.22.1
./configure --prefix=/path/to/install
make -j 4 && make install
```

## Install NCBI SRA Toolkit (for `fasterq-dump`)
Links:
1. https://github.com/ncbi/sra-tools
2. https://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?view=software

### Option 1: use pre-built binaries (but does not work on old Linux)
```bash
# Pre-built binaries does not work on old Linux
curl -OL https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/3.2.1/sratoolkit.3.2.1-ubuntu64.tar.gz
tar zxvf sratoolkit.3.2.1-ubuntu64.tar.gz
```

### Option 2: build from source
```bash
# Require ncbi-vdb
curl -L https://github.com/ncbi/ncbi-vdb/archive/refs/tags/3.2.1.tar.gz -o ncbi-vdb-3.2.1.tar.gz
tar zxvf ncbi-vdb-3.2.1.tar.gz
./configure --prefix=/path/to/install
make -j 4 && make install
# Do the symlink, otherwise sra-tools cannot find ncbi-vdb
cd ${HOME}
mkdir ncbi
cd ncbi
ln -s /path/to/install ncbi-vdb

# Install sra-tools
curl -L https://github.com/ncbi/sra-tools/archive/refs/tags/3.2.1.tar.gz -o sra-tools-3.2.1.tar.gz
tar zxvf sra-tools-3.2.1.tar.gz
cd sra-tools-3.2.1
./configure --prefix=/path/to/install
make -j 4 && make install
```

# Run the Workflow
```
cd local_stuff
sbatch sbatch/sbatch01.sra-search.v2.sh
```
