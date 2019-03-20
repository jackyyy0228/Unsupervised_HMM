import pickle as pkl
import numpy as np
import os,sys
## wav.scp , text, utt2spk

data_dir = 'data/'
train_data_path = data_dir + '/train'
test_data_path = data_dir + '/test'
train_data_correct_path = data_dir + '/train_correct'

train_wavs_names = pkl.load(open('/groups/public/guanyu/timit_new/audio/timit-train-meta.pkl','rb'))
train_wav_path  = '/groups/public/guanyu/timit_data/train' 
#train_trans_path = '/groups/public/wfst_decoder/exp/new_ori_nonmatched/decode_train/output.txt'
#train_trans_path = '/groups/public/wfst_decoder/exp/new_ref_matched/decode_train/output.txt'
#train_trans_path = '/groups/public/wfst_decoder/exp/new_ori_matched/decode_train/output.txt'
train_trans_path = sys.argv[1]


train_trans = pkl.load(open('/groups/public/guanyu/timit_new/audio/timit-train-phn.pkl','rb'))

test_wavs_names = pkl.load(open('/groups/public/guanyu/timit_new/audio/timit-test-meta.pkl','rb'))
test_wav_path  = '/groups/public/guanyu/timit_data/test' 
test_trans = pkl.load(open('/groups/public/guanyu/timit_new/audio/timit-test-phn.pkl','rb'))

def to_4_digits(integer):
    s = str(integer)
    l = len(s)
    for i in range(4-l):
        s = '0' + s
    return "A" + s

def prepare_wav_scp(wav_names, wav_path, tgt_path):
    length = len(wav_names['prefix'])
    wavs = wav_names['prefix']
    with open(tgt_path,'w') as f:
        for i in range(length):
            f.write(to_4_digits(i) + ' ' + os.path.join(wav_path, wavs[i]) + '.wav\n')

def prepare_utt2spk(length, tgt_path):
    with open(tgt_path,'w') as f:
        for i in range(length):
            f.write(to_4_digits(i) + ' ' + to_4_digits(i) + '\n')

def prepare_orc_text(trans, tgt_path):
    length = len(trans)
    with open(tgt_path,'w') as f:
        for i in range(length):
            f.write(to_4_digits(i) + ' ' + ' '.join(trans[i]) + '\n')

def prepare_text_from_output(src_path, tgt_path):
    L = []
    with open(src_path,'r') as f:
        for line in f:
            tokens = line.rstrip().split(' ')
            s = ' '.join(tokens[1:])
            L.append(s)
    with open(tgt_path,'w') as f:
        for i, s in enumerate(L):
            f.write(to_4_digits(i) + ' ' + s + '\n')




## train data
if not os.path.isdir(train_data_path):
    os.makedirs(train_data_path)
train_lengths = len(train_wavs_names['prefix'])
prepare_wav_scp(train_wavs_names, train_wav_path, os.path.join(train_data_path,'wav.scp'))
prepare_utt2spk(train_lengths, os.path.join(train_data_path,'utt2spk'))
prepare_utt2spk(train_lengths, os.path.join(train_data_path,'spk2utt'))
prepare_text_from_output(train_trans_path, os.path.join(train_data_path,'text'))

## train correct

if not os.path.isdir(train_data_correct_path):
    os.makedirs(train_data_correct_path)
train_lengths = len(train_wavs_names['prefix'])
prepare_wav_scp(train_wavs_names, train_wav_path, os.path.join(train_data_correct_path,'wav.scp'))
prepare_utt2spk(train_lengths, os.path.join(train_data_correct_path,'utt2spk'))
prepare_utt2spk(train_lengths, os.path.join(train_data_correct_path,'spk2utt'))
prepare_orc_text(train_trans, os.path.join(train_data_correct_path,'text'))


## test data
if not os.path.isdir(test_data_path):
    os.makedirs(test_data_path)
test_lengths = len(test_wavs_names['prefix'])
prepare_wav_scp(test_wavs_names, test_wav_path, os.path.join(test_data_path,'wav.scp'))
prepare_utt2spk(test_lengths, os.path.join(test_data_path,'utt2spk'))
prepare_utt2spk(test_lengths, os.path.join(test_data_path,'spk2utt'))
prepare_orc_text(test_trans, os.path.join(test_data_path,'text')) 





