import cv2
import time
from pathlib import Path
from ultralytics import YOLO
import torch


# Define paths to the YOLO model and input video
MODEL_PATH = r"C:\Capstone-Project-1\last.pt"
VIDEO_PATH = r"C:\Capstone-Project-1\DEMOVIDEO.mp4"


def main():
    # Check if GPU is available and use it if possible
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")

    # Load the YOLO model for segmentation
    model = YOLO(MODEL_PATH).to(device)

    # Open the input video file
    cap = cv2.VideoCapture(VIDEO_PATH)
    if not cap.isOpened():
        print(f"Error: Could not open video {VIDEO_PATH}")
        return

    # Get video properties for output configuration
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS)

    # Set up the output video writer
    output_path = str(Path(VIDEO_PATH).with_name(Path(VIDEO_PATH).stem + "_segmented.mp4"))
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')  # Codec for MP4
    out = cv2.VideoWriter(output_path, fourcc, fps, (width, height))

    # Variables for FPS calculation
    frame_count = 0
    start_time = time.time()

    # Process the video frame by frame
    while True:
        ret, frame = cap.read()
        if not ret:  # Exit if no more frames are available
            break

        # Perform segmentation on the current frame
        results = model(frame, conf=0.33, device=device)  # Confidence threshold of 0.33

        # Annotate the frame with segmentation results
        annotated_frame = results[0].plot()

        # Calculate and display FPS on the frame
        frame_count += 1
        elapsed_time = time.time() - start_time
        fps_text = f"FPS: {frame_count / elapsed_time:.2f}"
        cv2.putText(annotated_frame, fps_text, (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)  # Red text at top-left

        # Write the annotated frame to the output video
        out.write(annotated_frame)

        # Display the frame in a window
        cv2.imshow("Segmentation", annotated_frame)

        # Exit if 'q' is pressed
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    # Clean up: release video capture, writer, and close windows
    cap.release()
    out.release()
    cv2.destroyAllWindows()

    # Print the location of the saved output video
    print(f"Segmentation completed. Output saved to {output_path}")

# Run the script if executed directly
if __name__ == "__main__":
    main()
