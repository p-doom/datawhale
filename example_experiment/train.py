import uuid
import numpy as np
import logging
import logging_loki
from datetime import datetime
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.neural_network import MLPClassifier
from sklearn.metrics import log_loss

logging.basicConfig(level=logging.INFO)

experiment_name = "example_experiment"

handler = logging_loki.LokiHandler(
    url="http://localhost:3100/loki/api/v1/push",
    tags={"application": experiment_name},
    # auth=("admin", "admin"),
    version="1",
)

logger = logging.getLogger("example-logger")
logger.addHandler(handler)


# Define a simple neural network using scikit-learn
class SimpleNet:
    def __init__(self):
        self.model = MLPClassifier(
            hidden_layer_sizes=(128,), max_iter=1, warm_start=True
        )

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
            f"Epoch [{epoch + 1}/{epochs}], Loss: {loss:.4f}",
            extra={
                "metadata": {"epoch": f"{epoch}", "loss": f"{loss:.4f}"},
            },
        )


# Example usage
if __name__ == "__main__":
    ### START-OF-TRAINING BOILERPLATE
    experiment_id = str(uuid.uuid4())
    start_time = datetime.now().isoformat()
    logger.info(
        f"Experiment '{experiment_name}' started.",
        extra={
            "metadata": {
                "experiment_id": experiment_id,
                "experiment_name": experiment_name,
            }
        },
    )
    logger.info(
        f"Start Time: {start_time}", extra={"metadata": {"start_time": start_time}}
    )

    ### TRAINING CODE
    logger.info("Loading the iris dataset.")
    iris = load_iris()
    X, y = iris.data, iris.target

    logger.info("Creating dataset splits.")
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    logger.info("Standardize the data.")
    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_test = scaler.transform(X_test)

    model = SimpleNet()

    logger.info("Start model training.")
    train(model, X_train, y_train)

    ### END-OF-TRAINING BOILERPLATE
    end_time = datetime.now().isoformat()
    logger.info(f"End Time: {end_time}", extra={"metadata": {"end_time": end_time}})
    logger.info(f"Experiment '{experiment_name}' completed.")
