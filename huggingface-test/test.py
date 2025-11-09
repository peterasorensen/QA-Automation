from huggingface_hub import hf_hub_download
from ultralytics import YOLO

# Download the model
model_path = hf_hub_download(
    repo_id="MacPaw/yolov11l-ui-elements-detection",
    filename="ui-elements-detection.pt",
)

# Load and run prediction
model = YOLO(model_path)
results = model.predict("/Users/Apple/Desktop/spotifyq1.png")

# Display result
results[0].show()
