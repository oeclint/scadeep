#!/bin/bash
set +e

BIDMACH_SCRIPTS="${BASH_SOURCE[0]}"
if [ ! `uname` = "Darwin" ]; then
  BIDMACH_SCRIPTS=`readlink -f "${BIDMACH_SCRIPTS}"`
  export WGET='wget -c --no-check-certificate'
else
  while [ -L "${BIDMACH_SCRIPTS}" ]; do
    BIDMACH_SCRIPTS=`readlink "${BIDMACH_SCRIPTS}"`
  done
  export WGET='curl -C - --retry 2 -O'
fi

export BIDMACH_SCRIPTS=`dirname "$BIDMACH_SCRIPTS"`
cd ${BIDMACH_SCRIPTS}
BIDMACH_SCRIPTS=`pwd`
BIDMACH_SCRIPTS="$( echo ${BIDMACH_SCRIPTS} | sed 's+/cygdrive/\([a-z]\)+\1:+' )"

echo "====================="
echo "Downloading cleaned subset of MNT2014 Fr->En data (http://www-lium.univ-lemans.fr/~schwenk/cslm_joint_paper)"
echo "====================="
echo

DATADIR=${DATADIR:-${BIDMACH_SCRIPTS}/../data/mnt2014_fr-en}
mkdir -p ${DATADIR}
mkdir -p ${DATADIR}/h5_data
mkdir -p ${DATADIR}/smat_data
pushd ${DATADIR}

${WGET} http://www-lium.univ-lemans.fr/~schwenk/cslm_joint_paper/data/bitexts.tgz
if [ ! -d bitexts.selected ]; then
  tar -xvf bitexts.tgz
fi

pushd h5_data

# Need tqdm to run script
sudo -H $(which python) -m pip install tqdm

function preprocess_files() {
  echo "Preprocessing files:"
  for f in ${@:2}; do echo "- $f"; done
  echo "Saving binarized to $1"
  python ${BIDMACH_SCRIPTS}/preprocess_mnt2014.py \
    --binarized-text $1 --vocab ${VOCAB_SIZE} --count --overwrite \
    --chunk-size 51200 \
    --start-token 0 \
    --pad-token 1 \
    --unk-token 2 \
    "${@:2}"
}

VOCAB_SIZE=${VOCAB_SIZE:-25000}

EXTRACTED_DIR=${DATADIR}/bitexts.selected
FR_FILES=$(ls $EXTRACTED_DIR | grep '.fr.gz$' | xargs -I% echo "${EXTRACTED_DIR}/%" )
[ ! -f ${DATADIR}/h5_data/binarized.sorted.fr-0000.h5.gz ] && \
  preprocess_files binarized.sorted.fr ${FR_FILES}

EN_FILES=$(ls $EXTRACTED_DIR | grep '.en.gz$' | xargs -I% echo "${EXTRACTED_DIR}/%" )
[ ! -f ${DATADIR}/h5_data/binarized.sorted.en-0000.h5.gz ] && \
  preprocess_files binarized.sorted.en ${EN_FILES}

popd
H5_DIR=$PWD/h5_data/ SMAT_DIR=$PWD/smat_data/ \
  ${BIDMACH_SCRIPTS}/../bidmach ${BIDMACH_SCRIPTS}/process_mnt2014.ssc
