#!/bin/bash

stage=0

. ./cmd.sh
. ./path.sh

# you might not want to do this for interactive shells.
set -e

## Given input
prefix=nonmatch  # match or nonmatch
phone_map_txt=/groups/public/wfst_decoder/data/timit_new/phones/phones.60-48-39.map.txt
lm_text=/groups/public/wfst_decoder/data/timit_new/text/${prefix}_lm.48

## Parameters
nj=24
n_gram=9

## Output directory
phone_list_txt=data/phone_list.txt
dict=data/local/dict
lang=data/lang
lm_dir=data/${prefix}
lm=$lm_dir/$n_gram\gram.lm
lang_test=data/${prefix}/lang_test_$n_gram\gram
mfccdir=data/mfcc

if [ $stage -le 0 ]; then
  # Preprocess
  # Format phones.txt and get transcription
  python3 local/preprocess.py $phone_map_txt $phone_list_txt 
  
  echo "$0: Preparing dict."
  local/prepare_dict.sh $phone_list_txt $dict
  
  echo "$0: Generating lang directory."
  utils/prepare_lang.sh --position_dependent_phones false \
    $dict "<UNK>" data/local/lang $lang 
  echo "$0: Creating data." 
  
  cat $lang/words.txt | awk '{print $1 }'  | grep -v "<eps>"  |\
    grep -v "#0" > $lang/vocabs.txt 
  
  if [ ! -f $lm ]; then
    mkdir -p $lm_dir
    ngram-count -text $lm_text -lm $lm -vocab $lang/vocabs.txt -limit-vocab -order $n_gram
    mkdir -p $lang_test
    local/format_data.sh $lm $lang $lang_test
  fi
fi

if [ $stage -le 1 ]; then
  for part in train test; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $nj data/$part exp/make_mfcc/$part $mfccdir
    steps/compute_cmvn_stats.sh data/$part exp/make_mfcc/$part $mfccdir
  done
fi

if [ $stage -le 2 ]; then
  # train a monophone system
 # steps/train_mono.sh --boost-silence 1.25 --nj $nj --cmd "$train_cmd" \
  #                    data/train data/lang exp/mono
  # decode using the monophone model
  steps/decode.sh --nj $nj --cmd "$decode_cmd" exp/mono/graph \
                  data/train exp/mono/decode_train
fi


if [ $stage -le 3 ]; then
  new_data=data/train_mono
  prev_gmm=exp/mono
  ali=exp/progressive/mono_ali
  gmm=exp/progressive/tri1

  cp -r data/train $new_data
  cat $prev_gmm/decode_train/scoring_kaldi/penalty_1.0/9.txt | sort > $new_data/text

  steps/align_si.sh --boost-silence 1.25 --nj $nj --cmd "$train_cmd" \
                   $new_data data/lang $prev_gmm $ali

  # train a first delta + delta-delta triphone system on a subset of 5000 utterances
  steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
                        2500 15000 $new_data data/lang $ali $gmm

  utils/mkgraph.sh $lang_test \
                   $gmm $gmm/graph
  steps/decode.sh --nj $nj --cmd "$decode_cmd" $gmm/graph \
                  data/test $gmm/decode
  steps/decode.sh --nj $nj --cmd "$decode_cmd" $gmm/graph \
                  data/train_correct $gmm/decode_train
  rm -r $new_data
fi

if [ $stage -le 4 ]; then
  new_data=data/train_tri1
  prev_gmm=exp/progressive/tri1
  ali=exp/progressive/tri1_ali
  gmm=exp/progressive/tri2

  cp -r data/train $new_data
  cat $prev_gmm/decode_train/scoring_kaldi/penalty_1.0/9.txt | sort > $new_data/text

  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
                   $new_data data/lang $prev_gmm $ali

  # train a first delta + delta-delta triphone system on a subset of 5000 utterances
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
                          --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
                       $new_data data/lang $ali $gmm

  utils/mkgraph.sh $lang_test \
                   $gmm $gmm/graph
  steps/decode.sh --nj $nj --cmd "$decode_cmd" $gmm/graph \
                  data/test $gmm/decode
  steps/decode.sh --nj $nj --cmd "$decode_cmd" $gmm/graph \
                  data/train_correct $gmm/decode_train
  rm -r $new_data
fi

if [ $stage -le 5 ]; then
  new_data=data/train_tri2
  prev_gmm=exp/progressive/tri2
  ali=exp/progressive/tri2_ali
  gmm=exp/progressive/tri3
  cp -r data/train $new_data
  cat $prev_gmm/decode_train/scoring_kaldi/penalty_1.0/9.txt | sort > $new_data/text

  steps/align_si.sh --nj $nj --cmd "$train_cmd" \
                   $new_data data/lang $prev_gmm $ali

  # train a first delta + delta-delta triphone system on a subset of 5000 utterances
  steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
                       $new_data data/lang $ali $gmm

  utils/mkgraph.sh $lang_test \
                   $gmm $gmm/graph
  steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" $gmm/graph \
                  data/test $gmm/decode
  steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" $gmm/graph \
                  data/train_correct $gmm/decode_train
  rm -r $new_data
fi



exit 0
if [ $stage -le 6 ]; then
  echo ============================================================================
  echo "                        SGMM2 Training & Decoding                         "
  echo ============================================================================
  new_data=data/train_tri3
  prev_gmm=exp/progressive/tri3
  ali=exp/progressive/tri3_ali
  ubm=exp/progressive/ubm4
  gmm=exp/progressive/sgmm2

  cp -r data/train $new_data
  cat $prev_gmm/decode_train/scoring_kaldi/penalty_1.0/9.txt | sort > $new_data/text

  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
                   $new_data data/lang $prev_gmm $ali
  
  steps/train_ubm.sh --cmd "$train_cmd" \
   400 $new_data data/lang $ali $ubm

  steps/train_sgmm2.sh --cmd "$train_cmd" 7000 9000 \
   $new_data data/lang $ali $ubm/final.ubm $gmm

  utils/mkgraph.sh $lang_test \
                   $gmm $gmm/graph
  steps/decode_sgmm2.sh --nj $nj --cmd "$decode_cmd"\
   --transform-dir exp/progressive/tri3/decode $gmm/graph data/test \
   $gmm/decode
  
  steps/decode_sgmm2.sh --nj $nj --cmd "$decode_cmd"\
    --transform-dir exp/progressive/tri3/decode_train $gmm/graph data/train_correct \
   $gmm/decode_train
fi

if [ $stage -le 7 ]; then
  echo ============================================================================
  echo "                    MMI + SGMM2 Training & Decoding                       "
  echo ============================================================================
  new_data=data/train_sgmm2
  prev_gmm=exp/progressive/sgmm2
  ali=exp/progressive/sgmm2_ali
  ubm=exp/progressive/ubm4
  gmm=exp/progressive/sgmm2_denlats
  gmm2=exp/progressive/sgmm2_4_mmi_b0.1 

  
  if false; then
    cp -r data/train $new_data
    cat $prev_gmm/decode_train/scoring_kaldi/penalty_1.0/9.txt | sort > $new_data/text
    
    steps/align_sgmm2.sh --nj $nj --cmd "$train_cmd" \
     --transform-dir exp/progressive/tri3_ali --use-graphs true --use-gselect true \
     $new_data data/lang $prev_gmm $ali

    steps/make_denlats_sgmm2.sh --nj $nj --sub-split $nj \
     --acwt 0.2 --lattice-beam 10.0 --beam 18.0 \
     --cmd "$decode_cmd" --transform-dir exp/progressive/tri3_ali \
     $new_data data/lang $ali $gmm

    steps/train_mmi_sgmm2.sh --acwt 0.2 --cmd "$decode_cmd" \
     --transform-dir exp/progressive/tri3_ali --boost 0.1 --drop-frames true \
     $new_data data/lang $ali $gmm $gmm2
  fi
  for iter in 1 2 3 4; do
    steps/decode_sgmm2_rescore.sh --cmd "$decode_cmd" --iter $iter \
     --transform-dir exp/progressive/tri3/decode $lang_test data/test \
     $prev_gmm/decode $gmm2/decode_it$iter

    steps/decode_sgmm2_rescore.sh --cmd "$decode_cmd" --iter $iter \
     --transform-dir exp/progressive/tri3/decode_train $lang_test data/train_correct \
     $prev_gmm/decode_train $gmm2/decode_train_it$iter
  done
fi

if [ $stage -le 8 ]; then
  echo ============================================================================
  echo "                    DNN Hybrid Training & Decoding                        "
  echo ============================================================================

  # DNN hybrid system training parameters
  dnn_mem_reqs="--mem 1G"
  dnn_extra_opts="--num_epochs 20 --num-epochs-extra 10 --add-layers-period 1 --shrink-interval 3"
  new_data=data/train_tri3
  prev_gmm=exp/progressive/tri3
  ali=exp/progressive/tri3_ali
  dnn=exp/progressive/tri4_nnet

  steps/nnet2/train_tanh.sh --mix-up 5000 --initial-learning-rate 0.015 \
    --final-learning-rate 0.002 --num-hidden-layers 2  \
    --num-jobs-nnet $nj --cmd "$train_cmd" "${dnn_train_extra_opts[@]}" \
    $new_data data/lang $ali $dnn

  [ ! -d exp/tri4_nnet/decode_dev ] && mkdir -p exp/tri4_nnet/decode_dev
  decode_extra_opts=(--num-threads 6)
  steps/nnet2/decode.sh --cmd "$decode_cmd" --nj $nj "${decode_extra_opts[@]}" \
    --transform-dir exp/progressive/tri3/decode $prev_gmm/graph data/test \
    $dnn/decode | tee $dnn/decode/decode.log

  [ ! -d $dnn/decode_train ] && mkdir -p $dnn/decode_train
  steps/nnet2/decode.sh --cmd "$decode_cmd" --nj $nj "${decode_extra_opts[@]}" \
    --transform-dir exp/progressive/tri3/decode_train exp/tri3/graph data/train_correct \
    $dnn/decode_train | tee $dnn/decode_train/decode.log
fi


if [ $stage -le 9 ]; then
  echo ============================================================================
  echo "                    System Combination (DNN+SGMM)                         "
  echo ============================================================================

  dnn=exp/progressive/tri4_nnet
  gmm2=exp/progressive/sgmm2_4_mmi_b0.1
  combine=exp/progressive/combine
  for iter in 1 2 3 4; do
    local/score_combine.sh --cmd "$decode_cmd" \
     data/test $lang_test $dnn/decode \
     $gmm2/decode_it$iter $combine/decode_it$iter
  done
fi

if [ $stage -le 10 ]; then
  echo ============================================================================
  echo "               DNN Hybrid Training & Decoding (Karel's recipe)            "
  echo ============================================================================
  # TODO
  local/nnet/run_dnn.sh
  #local/nnet/run_autoencoder.sh : an example, not used to build any system,
fi

echo ============================================================================
echo "Finished successfully on" `date`
echo ============================================================================

exit 0
