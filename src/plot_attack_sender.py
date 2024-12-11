import pandas as pd
import matplotlib.pyplot as plt
import argparse
import os

# Load and parse the log file
def parse_log(file_path):
    data = []
    with open(file_path, "r") as file:
        logs = file.readlines()

    # Parsing the log file
    for line in logs:
        # Skip metadata lines
        if line.startswith("Log") or line.startswith("Pre attack phase") or line.startswith("Burst"):
            continue
        # Extract timestamp, bytes sent, and bytes acked
        try:
            timestamp, bytes_sent, bytes_acked = map(int, line.split(" : "))
            data.append((timestamp, bytes_sent, bytes_acked))
        except ValueError:
            continue

    # Create a DataFrame
    df = pd.DataFrame(data, columns=["timestamp", "bytes_sent", "bytes_acked"])
    df["timestamp"] = df["timestamp"] - df["timestamp"].min()  # Normalize timestamps

    return df

# Function to generate plots
def plot_data(df, title, y_col, ylabel, color, output_path, zoom_range=None):
    plt.figure(figsize=(12, 6))
    if zoom_range:
        zoomed_df = df[(df["timestamp"] >= zoom_range[0]) & (df["timestamp"] <= zoom_range[1])]
        plt.plot(zoomed_df["timestamp"], zoomed_df[y_col], label=title, color=color, linewidth=2)
    else:
        plt.plot(df["timestamp"], df[y_col], label=title, color=color, linewidth=2)
    plt.title(title, fontsize=14)
    plt.xlabel("Time (ms)", fontsize=12)
    plt.ylabel(ylabel, fontsize=12)
    plt.grid(True)
    plt.legend(fontsize=12)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)  
    plt.savefig(output_path)
    plt.show()

def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(description="Plot attack sender data.")
    parser.add_argument(
        "-t", "--type",
        required=True, type=str, action='store',
        help="Title of the plot (e.g., sender_ack)."
    )
    parser.add_argument(
        "-i", "--input",
        required=True, type=str, action='store',
        help="Input file path for the log file."
    )
    parser.add_argument(
        "-o", "--output",
        required=True, type=str, action='store',
        help="Output directory prefix for saving plots."
    )

    args = parser.parse_args()

    # Parse the input log file
    df = parse_log(args.input)
    if not os.path.exists(args.input):
        print(f"Error: The input file '{args.input}' does not exist.")
        exit(1)
    # print(f'{args.input}')
    # print(df)  # Debugging: Check the contents of the DataFrame
    assert df is not None, "Error: parse_log returned None. Check the input file format and parsing logic."

    # Generate and save the plots
    output_dir = args.output

    plot_data(
        df, f"{args.type}: Total Bytes Sent Over Time",
        "bytes_sent", "Total Bytes Sent", "blue",
        os.path.join(output_dir, "total_bytes_sent.pdf")
    )

    plot_data(
        df, f"{args.type}: Total Bytes Acked Over Time",
        "bytes_acked", "Total Bytes Acked", "green",
        os.path.join(output_dir, "total_bytes_acked.pdf")
    )

    plot_data(
        df, f"{args.type}: Total Bytes Sent Over Time (Zoomed: 5000ms to 10000ms)",
        "bytes_sent", "Total Bytes Sent", "blue",
        os.path.join(output_dir, "total_bytes_sent_zoomed.pdf"),
        zoom_range=(5000, 10000)
    )

    plot_data(
        df, f"{args.type}: Total Bytes Acked Over Time (Zoomed: 5000ms to 10000ms)",
        "bytes_acked", "Total Bytes Acked", "green",
        os.path.join(output_dir, "total_bytes_acked_zoomed.pdf"),
        zoom_range=(5000, 10000)
    )

    plot_data(
        df, f"{args.type}: Total Bytes Sent Over Time (Further Zoomed: 5000ms to 6000ms)",
        "bytes_sent", "Total Bytes Sent", "blue",
        os.path.join(output_dir, "total_bytes_sent_further_zoomed.pdf"),
        zoom_range=(5000, 6000)
    )

    plot_data(
        df, f"{args.type}: Total Bytes Acked Over Time (Further Zoomed: 5000ms to 6000ms)",
        "bytes_acked", "Total Bytes Acked", "green",
        os.path.join(output_dir, "total_bytes_acked_further_zoomed.pdf"),
        zoom_range=(5000, 6000)
    )

if __name__ == "__main__":
    main()