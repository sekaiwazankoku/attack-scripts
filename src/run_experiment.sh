#!/bin/bash

set -e
set -u
#set -x

log_uplink=false
MM_PKT_SIZE=1504  # bytes
# TCP MSS          = 1448 bytes
# Ethernet payload = 1500 bytes (= MSS + 20 [IP] + 32 [TCP])
# https://github.com/zehome/MLVPN/issues/26
# MM_PKT_SIZE      = 1504 bytes (= Ethernet payload + 4 [TUN overhead])
# Ethernet MTU     = 1518 bytes (= Ethernet payload + 18 [Ethernet])
# On the wire      = 1538 bytes (= Ethernet MTU + 20 [Preamble + IPG])

SCRIPT=$(realpath "$0")
SCRIPT_PATH=$(dirname "$SCRIPT")
export SCRIPT_PATH
EXPERIMENTS_PATH=$(realpath $SCRIPT_PATH/../)
GENERICCC_PATH=$(realpath $EXPERIMENTS_PATH/../ccas/genericCC)
COPA_ATT2_PATH=/usr/local/bin #for sender and receiver binaries

RAMDISK_PATH=/mnt/ramdisk
RAMDISK_DATA_PATH=$RAMDISK_PATH/$DATA_DIR
mkdir -p $RAMDISK_DATA_PATH

# Define the attack flag for copa attack2 (cross-traffic)
bbrAtt1=false
copaAtt=false
noAttBBR=false

# Check if the first argument is copa attack2
if [[ $1 == "bbrAtt1" ]]; then
    bbrAtt1=true
    shift  # Shift parameters so $1 becomes pkts_per_ms and others

elif [[ $1 == "copaAtt" ]]; then
    copaAtt=true
    shift

elif [[ $1 == "noAtt" ]]; then
    noAtt=true
    shift
fi

export bbrAtt1
export copaAtt # Exporting so it's available to sender.sh
export noAttBBR

pkts_per_ms=$1
delay_ms=$2
buf_size_bdp=$3
cca=$4
delay_uplink_trace_file=$5
cbr_uplink_trace_file=$6
downlink_trace_file=$7
port=$8
n_parallel=1

if [[ $CCA == "copa" ]]; then
    copaAtt2_port=$9
    delay_budget=${12}
    burst_duration=${13}
    inter_burst_time=${14}
    copa_attack_type=${15}  # value will be 1 or 2
    # tbf_size_bdp=${11}
fi

if [[ $CCA == "bbr" ]]; then
    #attack variables
    attack_rate=${11:-150}       # Dynamic attack rate input
    queue_size=${12:-0}          # Queue size for attack
    delay_budget=${13:-500}      # Max allowable delay for attack
fi

is_genericcc=false
if [[ $cca == genericcc_* ]]; then
    is_genericcc=true
fi

log_dmesg=true
if [[ n_parallel -gt 1 ]] || [[ is_genericcc == true ]]; then
    log_dmesg=false
fi

# echo "Delay Box args:"
# echo mahimahi_base: $MAHIMAHI_BASE

# Derivations
bdp_bytes=$(echo "$MM_PKT_SIZE*$pkts_per_ms*2*$delay_ms" | bc)
buf_size_bytes=$(echo "$buf_size_bdp*$bdp_bytes/1" | bc)

# Filenames according to attack type

if [[ $bbrAtt1 == true ]]; then 
    exp_tag="rate[$pkts_per_ms]-delay[$delay_ms]-buf_size[$buf_size_bdp]-cca[$cca]"

elif [[ $copaAtt == true ]] && [[ $copa_attack_type == 1 ]]; then 
    exp_tag="rate[$pkts_per_ms]-delay[$delay_ms]-buf_size[$buf_size_bdp]-cca[$cca]-delay_budget[$delay_budget]-mode[$mode]-duration[$burst_duration]-interval[$inter_burst_time]"

elif [[ $copaAtt == true ]] && [[ $copa_attack_type == 2 ]]; then 
    exp_tag="rate[$pkts_per_ms]-delay[$delay_ms]-buf_size[$buf_size_bdp]-cca[$cca]-delay_budget[$delay_budget]-bd[$burst_duration]-ib[$inter_burst_time]"

elif [[ $noAtt == true ]]; then 
    exp_tag="rate[$pkts_per_ms]-delay[$delay_ms]-buf_size[$buf_size_bdp]-cca[$cca]"

else
    exp_tag="rate[$pkts_per_ms]-delay[$delay_ms]-buf_size[$buf_size_bdp]-cca[$cca]-delay_budget[$delay_budget]-mode[$mode]-bd[$burst_duration]-ib[$inter_burst_time]"
fi

# tbf_size_bytes=false
# if [[ $tbf_size_bdp != false ]]; then
#     tbf_size_bytes=$(echo "$tbf_size_bdp*$bdp_bytes/1" | bc)
#     exp_tag+="-tbf_size_bdp[$tbf_size_bdp]"
# fi

iperf_log_path=$DATA_PATH/$exp_tag.json
if [[ -f $iperf_log_path ]]; then
    rm $iperf_log_path
fi

uplink_log_path=$RAMDISK_DATA_PATH/$exp_tag.log
if [[ -f $uplink_log_path ]]; then
    rm $uplink_log_path
fi

summary_path=$DATA_PATH/$exp_tag.summary
if [[ -f $summary_path ]]; then
    rm $summary_path
fi

uplink_log_path_delay_box=$RAMDISK_DATA_PATH/$exp_tag.jitter_log
if [[ -f $uplink_log_path_delay_box ]]; then
    rm $uplink_log_path_delay_box
fi

dmesg_log_path=$RAMDISK_DATA_PATH/$exp_tag.dmesg
if [[ $log_dmesg == true ]]; then
    if [[ -f $dmesg_log_path ]]; then
        rm $dmesg_log_path
    fi
fi

genericcc_logfilepath=$RAMDISK_DATA_PATH/$exp_tag.genericcc
if [[ -f $genericcc_logfilepath ]]; then
    rm $genericcc_logfilepath
fi

#for BBR jitter based attack logging
if [[ $bbrAtt1 == true ]]; then
    attack_log_path=$RAMDISK_DATA_PATH/$exp_tag-attack.log
    if [[ -f $attack_log_path ]]; then
        rm $attack_log_path
    fi
fi

#for Copa jitter based attack logging
if [[ $CCA == "copa" ]] && [[ $copa_attack_type == 1 ]]; then
        
    uplink_link_logfilepath=$RAMDISK_DATA_PATH/$exp_tag.uplink
    if [[ -f $uplink_link_logfilepath ]]; then
        rm $uplink_link_logfilepath
    fi
    echo "hey"

    downlink_link_logfilepath=$RAMDISK_DATA_PATH/$exp_tag.downlink
    if [[ -f $downlink_link_logfilepath ]]; then
        rm $downlink_link_logfilepath
    fi
    echo "ho"

    uplink_attack_logfilepath=$RAMDISK_DATA_PATH/$exp_tag.uplink.attack
    if [[ -f $uplink_attack_logfilepath ]]; then
        rm $uplink_attack_logfilepath
    fi
    echo "ya"

    downlink_attack_logfilepath=$RAMDISK_DATA_PATH/$exp_tag.downlink.attack
    if [[ -f $downlink_attack_logfilepath ]]; then
        rm $downlink_attack_logfilepath
    fi
    echo "tr"
    
fi

#For copa cross-traffic attack logging
if [[ $CCA == "copa" ]] && [[ $copa_attack_type == 2 ]]; then

    sender_attack_logfilepath=$RAMDISK_DATA_PATH/$exp_tag.sender.attack
    if [[ -f $sender_attack_logfilepath ]]; then
        rm $sender_attack_logfilepath
    fi
    echo "copa attack 2"

fi

# receiver_attack_logfilepath=$RAMDISK_DATA_PATH/$exp_tag.receiver.attack
# if [[ -f $receiver_attack_logfilepath ]]; then
#     rm $receiver_attack_logfilepath
# fi

# Start Server
if [[ $is_genericcc == true ]]; then
    echo "Using genericCC"
    $GENERICCC_PATH/receiver $port &
    server_pid=$!
else
    echo "Using iperf"
    iperf3 -s -p $port &
    server_pid=$!
fi
echo "Started server: $server_pid"

#Start the attacker server for cross-traffic attack on Copa
if [[ $CCA == "copa" ]] && [[ $copa_attack_type == 2 ]]; then
    echo "Starting attack receiver"
    $COPA_ATT2_PATH/receiver $copaAtt2_port &  #we need a dynamically changing port variable here so hat the pids don't interfere with each other
    attack_receiver_pid=$!
    echo "Attacker receiver port: $copaAtt2_port"
    echo "Started attack receiver: $attack_receiver_pid"
fi

if [[ $log_dmesg == true ]]; then
    # Start dmesg logging
    # https://unix.stackexchange.com/questions/390184/dmesg-read-kernel-buffer-failed-permission-denied
    # Run dmesg without sudo. Now we can have concurrent isolated experiments.
    # Ideally we want to do `dmesg --follow-new`, some versions don't have that :(
    sudo dmesg --clear
    dmesg --level info --follow --notime 1> $dmesg_log_path 2>&1 &
    dmesg_pid=$!
    echo "Started dmesg logging with: $dmesg_pid"

    # sudo -b dmesg -l info -W -t 1> $dmesg_log_path 2>&1
    # echo "Started dmesg logging"
    # # Due to -b flag, sudo immediately returns.
    # # There is no way to obtain the child's pid.
    # # (https://stackoverflow.com/questions/9315829/how-to-get-the-pid-of-command-running-with-sudo)
    # # Faced issues without the -b flag as well.
    # # (https://stackoverflow.com/questions/26109878/running-a-program-in-the-background-as-sudo)
    # # We are then resorting to kill all dmesg processes.
    # # This is not ideal on a shared machine.
    # # Currently tests are in an isolated VM, so this is fine.
fi

# Start client (behind emulated delay and link)
echo "Starting client"
export RAMDISK_DATA_PATH
export port
export copaAtt2_port
export cca
export iperf_log_path

export uplink_log_path
export cbr_uplink_trace_file
export downlink_trace_file
export sender_attack_logfilepath    #attack sender log copa attack2
#export receiver_attack_logfilepath
export buf_size_bytes
export genericcc_logfilepath
export tbf_size_bytes
export pkts_per_ms
export delay_ms
export burst_duration
export inter_burst_time

export copa_attack_type

export exp_tag

# echo "Delay box"
# echo delay_ms: $delay_ms
# echo uplink_log_path_delay_box: $uplink_log_path_delay_box
# echo uplink_trace_file: $uplink_trace_file
# echo downlink_trace_file: $downlink_trace_file

# Propagation delay box, then delay box (jittery trace) with inf buffer
# if [[ $tbf_size_bdp == false ]]; then
#     if [[ $log_uplink == true ]]; then
#         mm-delay $delay_ms \
#                     mm-link \
#                     $delay_uplink_trace_file \
#                     $downlink_trace_file \
#                     --uplink-log="$uplink_log_path_delay_box" \
#                     -- $SCRIPT_PATH/bottleneck_box.sh
#     else
#         mm-delay $delay_ms \
#                     mm-link \
#                     $delay_uplink_trace_file \
#                     $downlink_trace_file \
#                     -- $SCRIPT_PATH/bottleneck_box.sh
#     fi

# Check for CCA and attack type

if [[ $bbrAtt1 == true ]]; then # Condition for bbr attack 1
    echo "Jitter based attack scenario (attack 1) for BBR"
    mm-delay $delay_ms \
        mm-bbr-attack $attack_rate $queue_size $delay_budget --attack-log="$attack_log_path" \
        $SCRIPT_PATH/bottleneck_box.sh

elif [[ $copaAtt == true ]] && [[ $copa_attack_type == 1 ]]; then # Condition for copa attack 1
    echo "Jitter based attack scenario (attack 1) for Copa"
    mm-delay $delay_ms \
        mm-copa-attack $delay_budget $burst_duration $inter_burst_time $uplink_link_logfilepath $downlink_link_logfilepath $uplink_attack_logfilepath $downlink_attack_logfilepath \
        $SCRIPT_PATH/bottleneck_box.sh

elif [[ $copaAtt == true ]] && [[ $copa_attack_type == 2 ]]; then # Condition for copa attack 2
    echo "Cross-traffic Scenario (attack 2) for Copa"
    mm-delay $delay_ms \
        $SCRIPT_PATH/bottleneck_box.sh

# elif [[ $noAtt == true ]]; then
#     echo "No attack scenrio for BBR"
#     mm-delay $delay_ms \
#             $delay_uplink_trace_file \
#             $downlink_trace_file \
#             --uplink-log="$uplink_log_path_delay_box" \
#             -- $SCRIPT_PATH/bottleneck_box.sh
else 
    echo "No attack"
    mm-delay $delay_ms \
        $SCRIPT_PATH/bottleneck_box.sh
fi


if [[ $bbrAtt1 == true ]]; then
    if [[ -f $attack_log_path ]]; then
        mv $attack_log_path $DATA_PATH
    fi
fi

if [[ $CCA == "copa" ]] && [[ $copa_attack_type == 2 ]]; then
    mv $sender_attack_logfilepath $DATA_PATH
fi

if [[ $log_uplink == true ]]; then
    mv $uplink_log_path_delay_box $DATA_PATH
fi

if [[ $CCA == "copa" ]] && [[ $copa_attack_type == 1 ]]; then
    mv $uplink_link_logfilepath $DATA_PATH
    mv $downlink_link_logfilepath $DATA_PATH
    mv $uplink_attack_logfilepath $DATA_PATH
    mv $downlink_attack_logfilepath $DATA_PATH
fi

# else
#     echo "Not launching delay box as bottleneck is TBF only"
#     mm-delay $delay_ms $SCRIPT_PATH/bottleneck_box.sh
# fi

echo "Sleeping"  # so that iperf and mahimahi have some time to gracefully cleanup any sockets etc.
sleep 5

echo "Killing server"
kill $server_pid

if [[ $CCA == "copa" ]] && [[ $copa_attack_type == 2 ]]; then
    kill $attack_receiver_pid
fi

if [[ $log_dmesg == true ]]; then
    echo "Killing dmesg logging"
    kill $dmesg_pid
    # sudo killall dmesg
    mv $dmesg_log_path $DATA_PATH
fi

if [[ $is_genericcc == true ]] && [[ -f $genericcc_logfilepath ]]; then
    mv $genericcc_logfilepath $DATA_PATH
fi

set +e
set +u
#set +x