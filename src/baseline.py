"""TF-IDF + Logistic Regression baseline for complaint classification.

This script trains the final baseline model using the stripped-XXXX setting.
It saves:
1. The trained model pipeline.
2. The evaluation metrics as a JSON file.

The saved results will be used later to compare against DistilBERT and Cortex.
"""

import json
from pathlib import Path

import joblib
from load_data import load_split

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.feature_extraction.text import ENGLISH_STOP_WORDS
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.metrics import classification_report, f1_score


def build_pipeline(strip_xxxx=True):
    """Build a TF-IDF + Logistic Regression pipeline.

    Args:
        strip_xxxx:
            If True, the model ignores CFPB redaction tokens like XXXX and XX.
            We use True for the final baseline because it gave a slightly better Macro-F1.

    Returns:
        A scikit-learn Pipeline that includes text vectorization and classification.
    """

    # Start with the built-in English stopword list.
    # These are common words such as "the", "and", "is".
    stop_words = list(ENGLISH_STOP_WORDS)

    # Add CFPB redaction tokens to the stopword list.
    # These tokens appear when personal information is removed from the complaint text.
    if strip_xxxx:
        stop_words = stop_words + ["xxxx", "xx"]

    # The pipeline keeps preprocessing and model training together.
    # This helps avoid data leakage because TF-IDF is fitted only on training data.
    return Pipeline([
        (
            "tfidf",
            TfidfVectorizer(
                # Convert all words to lowercase so "Debt" and "debt" match.
                lowercase=True,

                # Remove English stopwords plus xxxx/xx redaction tokens.
                stop_words=stop_words,

                # Use both single words and two-word phrases.
                # Example: "debt" and "debt collector".
                ngram_range=(1, 2),

                # Ignore words or phrases that appear in fewer than 5 documents.
                # This removes rare typos and noise.
                min_df=5,

                # Limit the vocabulary size to keep training fast and memory-friendly.
                max_features=50000,
            ),
        ),
        (
            "clf",
            LogisticRegression(
                # Give the model enough iterations to converge.
                max_iter=1000,

                # Handle class imbalance by giving smaller classes more weight.
                class_weight="balanced",
            ),
        ),
    ])


def main():
    """Train the final baseline model, evaluate it, and save outputs."""

    # Load the fixed stratified train/test split from Snowflake.
    train_df, test_df = load_split()

    # X = complaint text.
    # y = product label that we want to predict.
    # Snowflake returns column names in uppercase.
    X_train = train_df["NARRATIVE"]
    y_train = train_df["PRODUCT"]

    X_test = test_df["NARRATIVE"]
    y_test = test_df["PRODUCT"]

    print("=== FINAL BASELINE: TF-IDF + Logistic Regression ===")
    print("Experiment setting: XXXX and XX redaction tokens stripped")

    # Build the final baseline model.
    pipe = build_pipeline(strip_xxxx=True)

    # Train the model only on the training set.
    pipe.fit(X_train, y_train)

    # Predict labels for the held-out test set.
    preds = pipe.predict(X_test)

    # Macro-F1 is the main metric because the dataset is imbalanced.
    macro_f1 = f1_score(y_test, preds, average="macro")

    print("\n=== PER-CLASS METRICS ===")
    print(classification_report(y_test, preds, digits=3))
    print(f"Macro-F1: {macro_f1:.3f}")

    # Create folders for saved model and results if they do not already exist.
    Path("models").mkdir(exist_ok=True)
    Path("results").mkdir(exist_ok=True)

    # Save the full pipeline:
    # TF-IDF vectorizer + Logistic Regression model.
    # This lets us reload the baseline later without retraining.
    joblib.dump(pipe, "models/baseline_tfidf_logreg.joblib")

    # Save metrics in a structured JSON file.
    # output_dict=True makes classification_report return a dictionary instead of plain text.
    report = classification_report(y_test, preds, digits=3, output_dict=True)

    # Add Macro-F1 explicitly so it is easy to find later.
    report["macro_f1"] = macro_f1

    with open("results/baseline_metrics.json", "w") as f:
        json.dump(report, f, indent=2)

    print("\nSaved files:")
    print("- models/baseline_tfidf_logreg.joblib")
    print("- results/baseline_metrics.json")


if __name__ == "__main__":
    main()