import numpy as np
import logging
import logging_loki
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.neural_network import MLPClassifier
from sklearn.metrics import log_loss

logging.basicConfig(level=logging.INFO)

handler = logging_loki.LokiHandler(
    # TODO: this is hardcoded
    url="http://localhost:3100/loki/api/v1/push", 
    tags={"application": "example_experiment"},
    # auth=("admin", "admin"),
    version="1",
)

logger = logging.getLogger("example-logger")
logger.addHandler(handler)

# Define a simple neural network using scikit-learn
class SimpleNet:
    def __init__(self):
        self.model = MLPClassifier(hidden_layer_sizes=(128,), max_iter=1, warm_start=True)

    def train(self, X, y):
        self.model.partial_fit(X, y, classes=np.unique(y))

    def predict(self, X):
        return self.model.predict_proba(X)

# Define a minimal training loop
def train(model, X_train, y_train, epochs=5):
    for epoch in range(epochs):
        model.train(X_train, y_train)
        predictions = model.predict(X_train)
        loss = log_loss(y_train, predictions)
        # This call is blocking. Follow the instruction at
        # https://github.com/GreyZmeem/python-logging-loki to send messages in a
        # different thread.
        logger.info(
            f'Epoch [{epoch+1}/{epochs}], Loss: {loss:.4f}', 
            extra={"tags": {"experiment": "example"}},
            )

# Example usage
if __name__ == "__main__":

    logger.info(
        "Loading the iris dataset.", 
        extra={"tags": {"experiment": "example"}},
        )
    iris = load_iris()
    X, y = iris.data, iris.target

    logger.info(
        "Creating dataset splits.", 
        extra={"tags": {"experiment": "example"}},
        )
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    logger.info(
        "Standardize the data.", 
        extra={"tags": {"experiment": "example"}},
        )
    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_test = scaler.transform(X_test)

    model = SimpleNet()

    logger.info(
        "Start model training.", 
        extra={"tags": {"experiment": "example"}},
        )
    train(model, X_train, y_train)
