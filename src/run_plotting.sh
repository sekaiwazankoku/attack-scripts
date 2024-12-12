#!/bin/bash

# delay_budget_choices=(0 40)
# size=1
# delay=40
# mode='auto'
# mode='constant_delta'

IFS=' ' read -r -a delay_budget_choices <<< "$1"
IFS=' ' read -r -a delay_ms_choices <<< "$2"
IFS=' ' read -r -a buf_size_bdp_choices <<< "$3"
IFS=' ' read -r -a burst_duration_choices <<< "$4"
IFS=' ' read -r -a inter_burst_choices <<< "$5"
copa_attack_type=$6

INPUT_ROOT_DIR=../data/uplink-droptail-vm/$CURRENT_TIME-$TEST_MSG
OUTPUT_ROOT_DIR=../data/output/$CURRENT_TIME-$TEST_MSG

if [[ $copa_attack_type == "copaAtt1" ]]; then
    for delay_budget in "${delay_budget_choices[@]}"; do
    for delay in "${delay_ms_choices[@]}"; do
    for size in "${buf_size_bdp_choices[@]}"; do
    for burst_duration in "${burst_duration_choices[@]}"; do
    for inter_burst_time in "${inter_burst_choices[@]}"; do

        OUTPUT_PREFIX=$OUTPUT_ROOT_DIR/delay[$delay]-delay_budget[$delay_budget]-mode[$mode]-duration[$burst_duration]-interval[$inter_burst_time]
        INPUT_DIR=$INPUT_ROOT_DIR/rate[8]-delay[$delay]-mode[$mode]
        INPUT_PREFIX=rate[8]-delay[$delay]-buf_size[$size]-cca[genericcc_markovian]-delay_budget[$delay_budget]-mode[$mode]-duration[$burst_duration]-interval[$inter_burst_time]
        python3 parse_mahimahi.py -i $INPUT_DIR/$INPUT_PREFIX.log -o $OUTPUT_PREFIX/mm-link
        python3 parse_mahimahi.py -i $INPUT_DIR/$INPUT_PREFIX.uplink -o $OUTPUT_PREFIX/mm-attack
        python3 parse_attack_log.py -t mahimahi -i $INPUT_DIR/$INPUT_PREFIX.uplink.attack -o $OUTPUT_PREFIX/mm-attack
        python3 parse_attack_log.py -t genericcc -i $INPUT_DIR/flow[1]-$INPUT_PREFIX.genericcc -o $OUTPUT_PREFIX/mm-attack
        python3 parse_stats.py -t 2 -i $INPUT_DIR -o $OUTPUT_ROOT_DIR
        
    done
    done
    done
    done
    done

elif [[ $copa_attack_type == "copaAtt2" ]]; then
    for delay_budget in "${delay_budget_choices[@]}"; do
    for delay in "${delay_ms_choices[@]}"; do
    for size in "${buf_size_bdp_choices[@]}"; do
    for burst_duration in "${burst_duration_choices[@]}"; do
    for inter_burst_time in "${inter_burst_choices[@]}"; do

        OUTPUT_PREFIX=$OUTPUT_ROOT_DIR/delay[$delay]-delay_budget[$delay_budget]-bd[$burst_duration]-ib[$inter_burst_time]
        INPUT_DIR=$INPUT_ROOT_DIR/rate[8]-delay[$delay]-mode[$mode]
        INPUT_PREFIX=rate[8]-delay[$delay]-buf_size[$size]-cca[genericcc_markovian]-delay_budget[$delay_budget]-bd[$burst_duration]-ib[$inter_burst_time]
        python3 parse_mahimahi.py -i $INPUT_DIR/$INPUT_PREFIX.log -o $OUTPUT_PREFIX/mm-link
        #python3 parse_mahimahi.py -i $INPUT_DIR/$INPUT_PREFIX.uplink -o $OUTPUT_PREFIX/mm-attack
        python3 parse_attack_log.py -t genericcc -i $INPUT_DIR/flow[1]-$INPUT_PREFIX.genericcc -o $OUTPUT_PREFIX/mm-attack
        python3 parse_attack_log.py -t sender_ack -i $INPUT_DIR/flow[1]-$INPUT_PREFIX.genericcc -o $OUTPUT_PREFIX/mm-attack
        python3 plot_attack_sender.py -t sender_ack -i $INPUT_DIR/$INPUT_PREFIX.sender.attack -o $OUTPUT_PREFIX/mm-attack
        python3 parse_stats.py -t 2 -i $INPUT_DIR -o $OUTPUT_ROOT_DIR
        
    done
    done
    done
    done
    done
fi
