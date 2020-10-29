import argparse
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.naive_bayes import CategoricalNB
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import accuracy_score
import pickle
import os
import numpy as np
from scipy.special import logsumexp

def predict_proba(X, clf, precision=None):
    if precision == None:
        feature_priors = clf.feature_log_prob_
        class_priors = clf.class_log_prior_
    else:
        feature_priors = list(map(lambda x: np.log(np.clip(np.round(np.exp(x), precision), 1e-12, None)), clf.feature_log_prob_))
        class_priors = list(map(lambda x: np.log(np.clip(np.round(np.exp(x), precision), 1e-12, None)), clf.class_log_prior_))
    jll = np.zeros((X.shape[0], 2))
    for i in range(X.shape[1]):
        indices = X.values[:, i]
        jll += feature_priors[i][:, indices].T
    total_ll = jll + class_priors
    
    log_prob_x = logsumexp(total_ll, axis=1)
    return np.argmax(np.exp(total_ll - np.atleast_2d(log_prob_x).T), axis=1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser('Categorical NBC generator.')
    parser.add_argument('-d', type=str, help="dataset path")
    parser.add_argument('-op', type=str, help="output pickle classifier path", default="")
    parser.add_argument('-oc', type=str, help="output NBC classifier path", default="")
    parser.add_argument('-oi', type=str, help="output inst path", default="")
    parser.add_argument('-ox', type=str, help="output xmap path", default="")
    parser.add_argument('-v', type=int, help="verbose", default=0)
    parser.add_argument('-p', type=int, help="precision of classifier", default=None)
    args = parser.parse_args()

    df = pd.read_csv(args.d)
    df.columns = [s.strip() for s in df.columns.values]      

    encoders = dict()
    min_categories = dict()
    for column in df.columns:
        if df[column].apply(type).eq(str).all():
            df[column] = df[column].str.strip()
        enc = LabelEncoder()
        enc.fit(df[column])
        df[column] = enc.transform(df[column])
        min_categories[column] = len(enc.classes_)
        encoders[column] = enc
    
    X = df.drop(df.columns[-1], axis=1)
    y = df[df.columns[-1]]

    X_train, X_test, y_train, y_test = train_test_split(X, y, train_size=0.8, random_state=0)
    clf = CategoricalNB(min_categories=np.array(list(min_categories.values())).astype(int)[:-1])
    clf.fit(X_train, y_train)
    
    if args.v:
        print("----------------------")
        print("Initial accuracy:")
        print("Train accuracy: ", accuracy_score(clf.predict(X_train), y_train))
        print("Test accuracy: ", accuracy_score(clf.predict(X_test), y_test))
        print("----------------------")

        if args.p is not None:
            print("----------------------")
            print("Rounded accuracy (precision=" + str(args.p) + "):")
            print("Train accuracy: ", accuracy_score(predict_proba(X_train, clf, args.p), y_train))
            print("Test accuracy: ", accuracy_score(predict_proba(X_test, clf, args.p), y_test))
            print("----------------------")

    if args.ox:
        if not os.path.exists(os.path.dirname(args.ox)):
            os.makedirs(os.path.dirname(args.ox))

        with open(args.ox, "w") as f:
            # --------- Target -----------
            enc = encoders[y.name]
            C = len(enc.classes_)
            f.write(str(C) + "\n")
            for category, target in zip(enc.classes_, enc.transform(enc.classes_)):
                f.write(str(target) + " " + str(category) + "\n")

            # --------- Features ---------
            n = X.shape[1]
            f.write(str(n) + "\n")

            f.write("0" + "\n")
            f.write(str(n) + "\n")
            for i, feature in enumerate(X.columns):
                f.write(str(i) + " " + str(feature) + "\n")
                enc = encoders[feature]
                f.write(str(len(enc.classes_)) + "\n")
                for category, label in zip(enc.classes_, enc.transform(enc.classes_)):
                    f.write(str(label) + " " + str(category) + "\n")

            """ 
            FUTURE DEVELOPMENT
            # Get types of features (categorical or continuous (=real-valued))
            dtypes = dict()
            for column in X.columns:
                if len(X[column].unique()) < (X.shape[0] / 3):
                    dtypes[column] = "categorical"
                else:
                    dtypes[column] = "continuous"
            # Real-valued features
            f.write(str(len(dict((k, v) for k, v in dtypes.items() if v == "continuous"))) + "\n")
            for i, (feature, dtype) in enumerate(dtypes.items()):
                if dtype == "continuous":
                    f.write(str(i) + " " + str(feature) + "\n")
                    enc = encoders[feature]
                    f.write(str(len(enc.classes_)) + "\n")
                    for category, label in zip(enc.classes_, enc.transform(enc.classes_)):
                        f.write(str(label) + " " + str(category) + "\n")
            
            # Categorical features
            f.write(str(len(dict((k, v) for k, v in dtypes.items() if v == "categorical"))) + "\n")
            for i, (feature, dtype) in enumerate(dtypes.items()):
                if dtype == "categorical":
                    f.write(str(i) + " " + str(feature) + "\n")
                    enc = encoders[feature]
                    f.write(str(len(enc.classes_)) + "\n")
                    for category, label in zip(enc.classes_, enc.transform(enc.classes_)):
                        f.write(str(label) + " " + str(category) + "\n")
            """

    if args.op:
        if not os.path.exists(os.path.dirname(args.op)):
            os.makedirs(os.path.dirname(args.op))
        pickle.dump(clf, open(args.op, "wb"))

    if args.oc:
        if not os.path.exists(os.path.dirname(args.oc)):
            os.makedirs(os.path.dirname(args.oc))

        with open(args.oc, "w") as f:
            n = len(clf.classes_)
            f.write(str(n) + "\n")
            class_priors = np.exp(clf.class_log_prior_)
            for i in class_priors:
                if args.p is not None:
                    f.write(str(np.round(np.format_float_positional(i, trim='-'), args.p)) + "\n")
                else:
                    f.write(str(np.format_float_positional(i, trim='-')) + "\n")
            m = X.shape[1]
            f.write(str(m) + "\n")

            feature_log_priors = clf.feature_log_prob_

            for feature_log_prior in feature_log_priors:
                feature_prior = np.exp(feature_log_prior)
                f.write(str(feature_prior.shape[1]) + "\n")
                for feature_class_prior in feature_prior:
                    for v in feature_class_prior:
                        if args.p is not None:
                            f.write(str(np.round(np.format_float_positional(v, trim='-'), args.p)) + " ")
                        else:
                            f.write(str(np.format_float_positional(v, trim='-')) + " ")
                    f.write("\n")

    if args.oi:
        if not os.path.exists(os.path.dirname(args.oi)):
            os.makedirs(os.path.dirname(args.oi))

        name = next(s for s in reversed(args.oi.split("/")) if s)
        for i, (_, sample) in enumerate(X.iterrows()):
            path = os.path.join(args.oi, name + "." + str(i+1) + ".txt")
            with open(path, "w") as f: 
                f.write(str(len(sample)) + "\n")
                for value in sample:
                    f.write(str(value) + "\n")
                f.write(str(clf.predict([sample])[0]) + "\n")

