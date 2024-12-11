import matplotlib.pyplot as plt
import numpy as np
from common import try_except_wrapper
from typing import Literal
import argparse
import os

GENERICCC_PKT_SIZE = 1440
BITS_PER_BYTE = 8
MSEC_PER_SEC = 1000

def plot(x, y, fpath,
            xlabel="", ylabel="",
            yscale: Literal['linear', 'log', 'symlog', 'logit'] = 'linear',
            title=""):
    fig, ax = plt.subplots()

    merged_list = [(x[i], y[i]) for i in range(len(x))]
    merged_list.sort(key=lambda x: x[0])
    x = [merged_list[i][0] for i in range(len(merged_list))]
    y = [merged_list[i][1] for i in range(len(merged_list))]
    
    ax.scatter(x, y)
    ax.plot(x, y)
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    # ax.set_yscale(yscale)
    ax.set_title(title)
    fig.set_tight_layout(True)
    fig.savefig(fpath)
    plt.close(fig)


def get_data(input_path, log_name):
    data = {}
    dirs = os.listdir(input_path) 
    for dir in dirs:
        log_path = os.path.join(input_path, dir, 'mm-link', log_name)
        f = open(log_path)
        items = f.read().strip().split(', ')
        for item in items:
            pair = item.split(' ')
            if data.get(pair[0]) is None:
                data[pair[0]] = []
            data[pair[0]].append(float(pair[1]))
    return data


def plot_first_attack(args):
    log_name = "statistics.log"
    data = get_data(args.input, log_name)

    if not os.path.exists(args.output):
        os.makedirs(args.output)

    plot(data["delay_budget"], data["link_rate"], os.path.join(args.output, 'delay_budget_link_rate.pdf'),
            xlabel='Delay Budget (ms)', ylabel='Avg Ack Rate (Mbps)')
    plot(data["duration"], data["link_rate"], os.path.join(args.output, 'duration_link_rate.pdf'),
            xlabel='Delay Duration (ms)', ylabel='Avg Ack Rate (Mbps)')
    plot(data["interval"], data["link_rate"], os.path.join(args.output, 'interval_link_rate.pdf'),
            xlabel='Inter Delay Time (ms)', ylabel='Avg Ack Rate (Mbps)')


def parse_file_name(file_name):
    params = {}
    prefix = file_name.split('.')[0]
    items = prefix.split('-')
    for item in items:
        tokens = item.replace(']', '').replace('[', ' ').split(' ')
        if tokens[1].isnumeric():
            params[tokens[0]] = int(tokens[1])
        else:
            params[tokens[0]] = tokens[1]
    return params
    

def parse_genericcc_log(log, data):
    start_data = (None, None)
    end_data = (None, None)
    first_timestamp = None

    with open(log, 'r') as f:
        cnt = 0
        for line in f:
            line = line.strip()
            if not line.startswith('(onACK)'):
                continue
            line = line[7:]
            items = line.split(', ')
            log_time = float(items[0].split(' ')[1])
            total_pkts = int(items[1].split(' ')[1])

            # Normalize the timestamp
            if first_timestamp is None:
                first_timestamp = log_time
            time = (log_time - first_timestamp) / MSEC_PER_SEC  # Convert to seconds

            # Skip timestamps in the volumetric phase
            if time < 5 or time > 30:
                continue

            if cnt == 0:
                start_data = (log_time, total_pkts)

            end_data = (log_time, total_pkts)

            cnt += 1

    # Compute average ack rate
    # TODO: fix the computation: skip data points in slow start / volumetric attack phase
    total_time = (end_data[0]-start_data[0]) / MSEC_PER_SEC
    total_mbits = (end_data[1]-start_data[1]) * GENERICCC_PKT_SIZE * BITS_PER_BYTE / 1e6

    avg_ack_rate = total_mbits / total_time

    return avg_ack_rate


def parse_sender_attack_log(log, data):
    start_data = (None, None)
    end_data = (None, None)
    first_timestamp = None

    with open(log, 'r') as f:
        cnt = 0
        is_init = True
        for line in f:
            if line.startswith('End of pre attack phase'):
                is_init = False
                continue
            if is_init or line.startswith('Average Throughput'):
                continue
            tokens = line.strip().split(' : ')
            log_time = int(tokens[0])
            bytes = int(tokens[2])

            # Normalize the timestamp
            if first_timestamp is None:
                first_timestamp = log_time
            time = (log_time - first_timestamp) / MSEC_PER_SEC  # Convert to seconds

            # Skip timestamps in the volumetric phase
            if time < 5 or time > 30:
                continue
            
            if cnt == 0:
                start_data = (log_time, bytes)
            
            end_data = (log_time, bytes)
            
            cnt += 1

    # Compute average ack rate
    # TODO: fix the computation: skip data points in slow start / volumetric attack phase
    total_time = (end_data[0]-start_data[0]) / MSEC_PER_SEC
    total_mbits = (end_data[1]-start_data[1]) * BITS_PER_BYTE / 1e6

    avg_ack_rate = total_mbits / total_time

    return avg_ack_rate


def get_second_attack_data(input_path):
    # data = {inter_burst_time: [victim_throughput, attacker_throughput]}
    data = {}
    files = os.listdir(input_path) 
    for file in files:
        params = parse_file_name(file)
        inter_burst_time = params['ib']
        if data.get(inter_burst_time) is None:
            data[inter_burst_time] = [0]*2

        if file.endswith('.genericcc'):
            data[inter_burst_time][0] = parse_genericcc_log(os.path.join(input_path, file), data)
        elif file.endswith('.sender.attack'):
            data[inter_burst_time][1] = parse_sender_attack_log(os.path.join(input_path, file), data)
    
    return data


def plot_second_attack(args):
    data = get_second_attack_data(args.input)
    # TODO: plot the data
    # plot victim throughput vs attacker throughput 
    # plot victim throughput vs inter burst

    # Extract the data for plotting
    inter_burst_times = sorted(data.keys())  # x-axis for the second plot
    victim_throughput = [data[ib][0] for ib in inter_burst_times]  # y-axis for both plots
    attacker_throughput = [data[ib][1] for ib in inter_burst_times]  # x-axis for the first plot

    # First plot: Attacker Throughput vs Victim Throughput
    plot(attacker_throughput, victim_throughput,
         os.path.join(args.output, 'attacker_throughput_victim_throughput.pdf'),
         xlabel='Attacker Throughput (Mbps)', ylabel='Victim Throughput (Mbps)')

    # Second plot: Inter Burst Time vs Victim Throughput
    plot(inter_burst_times, victim_throughput,
         os.path.join(args.output, 'inter_burst_victim_throughput.pdf'),
         xlabel='Inter Burst Time (ms)', ylabel='Victim Throughput (Mbps)')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-t', '--type', required=True,
        type=int, action='store',
        help='copa attack type')
    parser.add_argument(
        '-i', '--input', required=True,
        type=str, action='store',
        help='path to mahimahi trace')
    parser.add_argument(
        '-o', '--output', required=True,
        type=str, action='store',
        help='path output figure')
    args = parser.parse_args()

    if args.type == 1:
        plot_first_attack(args)
    elif args.type == 2:
        # input: ../data/uplink-droptail-vm/<timestamp>/rate[]-delay[]-mode[]/
        plot_second_attack(args)


if(__name__ == "__main__"):
    main()