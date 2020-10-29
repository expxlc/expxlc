# Demo of xpxlc


## Contents
* [Overview](#overview)
* [Setup](#setup)
* [Explaining Categorical Classifiers](#cxps)
* [Notes](#notes)


## <a name=overview> Overview </a>
`xpxlc` allows users to compute explanations of [Naive Bayes Classifiers](https://en.wikipedia.org/wiki/Naive_Bayes_classifier) (NBCs). NBCs should be represened in the XLC format, and some examples are included in the demo distribution.

This document aims to guide users through the use of  `xpxlc` , which implements the algorithms described in the NeurIPS'20 submission. `xpxlc` generates explanations starting from classifiers represented in the XLC text format.


## <a name=setup> Setup </a>
A number of intermediate tools are used to use scikit for learning NBCs, and then for translating the scikit's pickle format to the text format used by `xpxlc`. To simplify the demo, these steps are by-passed, and the resulting files included in the demo repository.


## <a name=cxps> Explaining Classifiers with Categorical Features </a>
The most general case considered in the `xpxlc` toolset assumes categorical features. (Technically, the theory can work with real-valued features, but this is not yet implemented.)

### Prerequisite 

Current Categorical Naive Bayes classifier implementation has certain flaws. Development version of scikit-learn corrects these flaws which are necessary to use XPXLC. 

`& pip install --pre --extra-index https://pypi.anaconda.org/scipy-wheels-nightly/simple scikit-learn`

### Training NBC (skippable if using already processed datasets)

Given a categorical dataset, the tool for training and generating an NBC is `generator_cnbc.py`.
In the process, it encodes features if needed and generates auxiliary files (encoding map, classifier, instances). The command to execute is:

```
& python ./scripts/generator_cnbc.py 
      -d <dataset-path> 
      -oc <out-classifier-path> 
      -op <out-pickle-classifier-path> 
      -ox <out-xmap-path> 
      -oi <out-instances-path>
```

### Convert classifier to XLC (skippable if using already processed datasets)

Given a NBC file, the tool for converting it into an [XLC](#notes) is `cnbc2xlc` and the command to execute is:

`& ./scripts/cnbc2xlc -f <classifier-path> -o <out-path>`

### Running XPXLC
In the case of NBCs working with categorical features, and given an [XLC](#notes) file and associated (categorical) instance file, the tool for producing explanations is `xpxlc`, and the command to execute is:

`% ./scripts/xpxlc -C -s -t -n NNN -f <xlc-file> -i <cinst-file> -m <xmap-file>`

As explained above, for categorical datasets it is convenient to use an [XMAP](#notes) file.

Moreover, NNN denotes the number of explanations to compute. In case option `-n NNN` is not specified, the `xpxlc` tool computes all explanations, time permitting. Clarification of the additional options can be obtained by running `xpxlc` with the `-h` option.


### Validating Explanations
By replacing options '`-s -t -n NNN`' in the command above with the option '`-c <xpl-file>`', xpxlc will validate the explanations in the [XXPL](#notes) file, indicating whether these are PI-explanations and if so, whether redundancy exists.


## <a name="notes"> Notes </a>
The text formats mentioned in this document are outlined in the following files:

* CNBC Format: see file $ROOT/fmts/CNBC-Format.txt
* XLC Format: see file $ROOT/fmts/XLC-Format.txt
* XMAP Format: see file $ROOT/fmts/XMAP-Format.txt
* XXPL Format: see file $ROOT/fmts/XXPL-Format.txt
* Inst Format: see file $ROOT/fmts/Inst-Format.txt
