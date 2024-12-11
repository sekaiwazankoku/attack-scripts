import matplotlib.pyplot as plt
import numpy as np
from common import try_except_wrapper
from typing import Literal
import argparse
import os

def plot(x, y, fpath,
            xlabel="", ylabel="",
            yscale: Literal['linear', 'log', 'symlog', 'logit'] = 'linear',
            title=""):
    fig, ax = plt.subplots()
    ax.plot(x, y)
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    # ax.set_yscale(yscale)
    ax.set_title(title)
    fig.set_tight_layout(True)
    fig.savefig(fpath)
    plt.close(fig)

def parse_log(data, fpath):
    f = open(fpath)
    for line in f:
        # Skip sender/receiver logs
        if line.startswith("(onPKTSent)") or line.startswith("(onACK)"):
            continue
        tokens = line.split(", ")
        for i, token in enumerate(tokens):
            pair = token.split(" ")
            data[pair[0]].append(float(pair[1]))
    f.close()
    return data

# def parse_sender_receiver_logs(fpath, output_dir):
#     sender_data = {"timestamp": [], "throughput": []}
#     receiver_data = {"timestamp": [], "throughput": []}
#     #sender_data = {"timestamp": [], "num_packets": []}
#     #receiver_data = {"timestamp": [], "num_packets": []}

#     with open(fpath, "r") as f:
#         for line in f:
#             if line.startswith("(onPKTSent)"):
#                 tokens = line.split(", ")
#                 timestamp = float(tokens[0].split(" ")[1])
#                 throughput = float(tokens[1].split(" ")[1])
#                 if throughput != float("inf"):  # Ignore logs with "inf" throughput
#                     sender_data["timestamp"].append(timestamp)
#                     sender_data["throughput"].append(throughput)
#             elif line.startswith("(onACK)"):
#                 tokens = line.split(", ")
#                 timestamp = float(tokens[0].split(" ")[1])
#                 throughput = float(tokens[1].split(" ")[1])
#                 if throughput != float("inf"):  # Ignore logs with "inf" throughput
#                     receiver_data["timestamp"].append(timestamp)
#                     receiver_data["throughput"].append(throughput)

#     os.makedirs(output_dir, exist_ok=True)
#     # Plot Sender Throughput
#     plot(sender_data["timestamp"], sender_data["throughput"],
#          os.path.join(output_dir, 'victim_sending_rate.pdf'),
#          xlabel='Time (ms)', ylabel='Throughput (Mbps)', title='Victim Sending Rte Over Time')

#     # Plot Ack Throughput
#     plot(receiver_data["timestamp"], receiver_data["throughput"],
#          os.path.join(output_dir, 'victim_ack_rate.pdf'),
#          xlabel='Time (ms)', ylabel='Throughput (Mbps)', title='Ack Rate Over Time')

def parse_sender_ack_logs(fpath, output_dir):
    sender_data = {"timestamp": [], "num_packets": []}
    acked_data = {"timestamp": [], "num_packets": []}

    with open(fpath, "r") as f:
        for line in f:
            # Check if the line logs sender data
            if line.startswith("(onPKTSent)"):
                tokens = line.split(", ")
                timestamp = float(tokens[0].split(" ")[1])  # Extract timestamp
                num_packets = int(tokens[1].split(" ")[1])  # Extract num_packets
                sender_data["timestamp"].append(timestamp)
                sender_data["num_packets"].append(num_packets)

            # Check if the line logs receiver acknowledgment data
            elif line.startswith("(onACK)"):
                tokens = line.split(", ")
                timestamp = float(tokens[0].split(" ")[1])  # Extract timestamp
                num_packets = int(tokens[1].split(" ")[1])  # Extract num_packets
                acked_data["timestamp"].append(timestamp)
                acked_data["num_packets"].append(num_packets)

    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)

    # Plot Sender Packets
    plot(
        sender_data["timestamp"],
        sender_data["num_packets"],
        os.path.join(output_dir, 'victim_sender_num_packets.pdf'),
        xlabel='Time (ms)',
        ylabel='Number of Packets',
        title='Number of Packets Sent Over Time'
    )

    # Plot Receiver Packets
    plot(
        acked_data["timestamp"],
        acked_data["num_packets"],
        os.path.join(output_dir, 'victim_ack_num_packets.pdf'),
        xlabel='Time (ms)',
        ylabel='Number of Packets',
        title='Number of Packets Acknowledged Over Time'
    )


def parse_genericcc_log(fpath, output_dir):
    data = {"timestamp": [], "min_rtt": [], "rtt": [], "queuing_delay": [], "delta": []}
    data = parse_log(data, fpath)

    os.makedirs(output_dir, exist_ok=True)
    plot(data["timestamp"], data["min_rtt"], os.path.join(output_dir, 'genericcc_min_rtt.pdf'),
            xlabel='Time (ms)', ylabel='RTT (ms)')
    plot(data["timestamp"], data["rtt"], os.path.join(output_dir, 'genericcc_rtt.pdf'),
            xlabel='Time (ms)', ylabel='RTT (ms)')
    plot(data["timestamp"], data["queuing_delay"], os.path.join(output_dir, 'genericcc_queuing_delay.pdf'),
            xlabel='Time (ms)', ylabel='Queuing Delay (ms)')
    plot(data["timestamp"], data["delta"], os.path.join(output_dir, 'genericcc_delta.pdf'),
            xlabel='Time (ms)', ylabel='delta')


def parse_mahimahi_log(fpath, output_dir):
    data = {"timestamp": [], "delay": []}
    data = parse_log(data, fpath)

    os.makedirs(output_dir, exist_ok=True)
    plot(data["timestamp"][:500], data["delay"][:500], os.path.join(output_dir, 'mahimahi_delay.pdf'),
            xlabel='Time (ms)', ylabel='Computed Delay (ms)')


# @try_except_wrapper
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-t', '--type', required=True,
        type=str, action='store',
        help='attack log type: genericcc, mahimahi')
    parser.add_argument(
        '-i', '--input', required=True,
        type=str, action='store',
        help='path to mahimahi trace')
    parser.add_argument(
        '-o', '--output', required=True,
        type=str, action='store',
        help='path output figure')
    args = parser.parse_args()

    if args.type == "genericcc":
        parse_genericcc_log(args.input, args.output)
    elif args.type == "mahimahi":
        parse_mahimahi_log(args.input, args.output)
    elif args.type == "sender_ack":
         parse_sender_ack_logs(args.input, args.output)
    else:
        print("No matching parsing function")


if(__name__ == "__main__"):
    main()
