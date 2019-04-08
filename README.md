# unsupervised_HMM

This is the implementation of unsupervised HMM in [our paper](#Citation).  HMM training followed the standard recipes of [Kaldi in TIMIT](https://github.com/kaldi-asr/kaldi/tree/master/egs/timit), except that we used the GAN-generated phoneme sequence[2](#Reference) to train the first  mono-phone model. Then, we used the HMMs to retranscribe the training set and used it to train the next HMM.

<!--If you find this project helpful for your research, please do consider to cite our paper, thanks! -->

## How to use

### Dependencies

-kaldi 

-srilm (can be built with kaldi/tools/install_srilm.sh)

### Path

- Modify path.sh with your path of kaldi and srilm.

### Unsupervised HMM training

```
bash run.sh
```

### Alignment

- Get phoneme alignment from lattices in decoding directory.

```
$  bash scripts/lat_lat_to_phones.sh $decode_dir
```

## Results

In "Match" case, 

|HMMs                    | iter1  |  iter2  | iter3  |
|---------------------| ------- |-------- |-------- |
|mono                    | 42.34 | 36.36 | 34.78 |
|tri1                         | 34.63 | 29.96 | 28.82 |
|tri2(LDA+MLLT) | 31.77 | 27.54 | 26.62 |
|tri3(LDA+MLLT) | **30.73** | **27.07** | **26.11** |

In "Nonmatch" case,

|HMMs                    | iter1  |  iter2  | iter3  |
|---------------------| ------- |-------- |-------- |
|mono                    | 43.84 | 39.52 | 38.00 |
|tri1                         | 41.89 | 37.26 | 35.49 |
|tri2(LDA+MLLT) | 40.00 | 35.71 | 33.48 |
|tri3(LDA+MLLT) | **39.48** | **35.46** | **33.07** |



## ToDo

- Use lexicon file to transcribe phoneme sequences into word sequences.

- Test the performane at word-level (WER)

## Reference
1.[Unsupervised Speech Recognition via Segmental Empirical Output Distribution Matching](https://arxiv.org/abs/1812.09323), Chih-Kuan Yeh*et al.* 

2.Completely Unsupervised Phoneme Recognition By A Generative AdversarialNetwork Harmonized With Iteratively Refined Hidden Markov Models,  Kuan-Yu Chen, Che-Ping Tsai *et.al.*



