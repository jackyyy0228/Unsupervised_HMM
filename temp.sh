#!/bin/bash
root=/groups/public/wfst_decoder/exp/
set -e

typ=match
for dir in new_ref2_matched; do
  dnn_output=$root/$dir/decode_train/scoring_kaldi/penalty_1.0/20.txt
  dnn_test_output=$root/$dir/decode_test/scoring_kaldi/penalty_1.0/20.txt
  exp=exp/$dir
  mkdir -p $exp
  sorted_output=$exp/dnn_train_output.txt
  sorted_test_output=$exp/dnn_test_output.txt

  cat $dnn_output | sort > $sorted_output
  cat $dnn_test_output | sort > $sorted_test_output
  
  echo "DNN:" >> $exp/log 
  python3 local/eval_per.py test $sorted_test_output # >> $exp/log
  
  rm -rf data/train data/test data/train_correct
  
  python3 local/prepare_data.py $sorted_output
  bash exp.sh $typ $exp 

done

typ=nonmatch
for dir in new_ref2_nonmatched ; do
  dnn_output=$root/$dir/decode_train/scoring_kaldi/penalty_1.0/20.txt
  dnn_test_output=$root/$dir/decode_test/scoring_kaldi/penalty_1.0/20.txt
  exp=exp/$dir
  mkdir -p $exp
  sorted_output=$exp/dnn_train_output.txt
  sorted_test_output=$exp/dnn_test_output.txt

  cat $dnn_output | sort > $sorted_output
  cat $dnn_test_output | sort > $sorted_test_output

  echo "DNN:" >> $exp/log 
  python3 local/eval_per.py test $sorted_test_output # >> $exp/log
  
  rm -rf data/train data/test data/train_correct

  python3 local/prepare_data.py $sorted_output
  bash exp.sh $typ $exp 
done
