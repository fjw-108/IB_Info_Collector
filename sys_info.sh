#!/bin/bash

# Script to collect system and Infiniband (IB) NIC details

# Output file named after the hostname
  HOSTNAME=$(hostname)
  OUTPUT_FILE="${HOSTNAME}_info.txt"

## clean up the old files
  rm -rf /tmp/iboutput/*
  rm -rf $OUTPUT_FILE

# Function to run list of commands and output to file
execute_commands() {

  local commands=("$@")

  echo "##################################################"
  for cmd in "${commands[@]}"; do
          echo "Executing: $ $cmd" | tee -a $OUTPUT_FILE
          eval $cmd | tee -a $OUTPUT_FILE
          echo "-------------------------" | tee -a $OUTPUT_FILE
  done
}


# check NIC interface detail
check_nic_info() {

echo "==== Collecting IB Interface Counters ====" >> "$OUTPUT_FILE"

# Find all IB interfaces starting with 'ibp'
IB_INTERFACES=$(ls /sys/class/net | grep ^ibp)

# Check if any IB interfaces are found
if [ -z "$IB_INTERFACES" ]; then
  echo "No IB interfaces found." >> "$OUTPUT_FILE"
  echo "No IB interfaces found. Exiting."
  exit 1
fi

# Loop through each IB interface and run ethtool
for iface in $IB_INTERFACES; do
  echo "\n==== Interface: $iface ====" >> "$OUTPUT_FILE"
  ethtool $iface >> $OUTPUT_FILE
  echo "Running ethtool for $iface... inteface counters" >> $OUTPUT_FILE
  ethtool -S $iface >> "$OUTPUT_FILE" 2>&1 || echo "ethtool not supported for $iface" >> "$OUTPUT_FILE"
  echo "Running ethtool for $iface... inteface version" >> $OUTPUT_FILE
  ethtool -i  $iface >> "$OUTPUT_FILE" 2>&1 || echo "ethtool not supported for $iface" >> "$OUTPUT_FILE"
  echo "Running IP Link show counters on each Interface : ip -s link show $iface" >> $OUTPUT_FILE
  eval ip -stats link show $iface | tee -a $OUTPUT_FILE
  echo " Check IB Errors in interface ibqueryerrors $iface" >> $OUTPUT_FILE
  ibqueryerrors $iface >> $OUTPUT_FILE
  echo "Done with $iface." >> "$OUTPUT_FILE"

done

}

## This funcation needs some work, need to check the mst -d xxx q outpuput
mst_querry() {
# List all Mellanox devices
echo "------ MST Querry ---------" >> $OUTPUT_FILE
DEVICES=$(mst status  | awk '/\/dev\/mst/ {print $1}')

for dev in $DEVICES; do
    echo "Running mstconfig for device: $dev" >> $OUTPUT_FILE
    eval mstconfig -d $dev q | tee -a $OUTPUT_FILE
done
echo "------ MST Querry DONE---------" >> $OUTPUT_FILE
}
system_commands=(
        "dmidecode"
        "lscpu"
        "numastat"
        "free -h"
        "lshw -short"
        "lstopo -x"
        "lstopo --distance"
        "numactl --hardware"
        "ulimit"
        "cat /proc/sys/kernel/numa_balancing"
        "sysctl status kernel"
        "cat /etc/sysctl.conf"
)

network_commands=(
        "ip address"
        "rdma link"
        "ifconfig"
        "ifconfig -a | grep ib"
        "lsnet"
        "ip -s link"
        "dmesg | grep  -i link"
        "cat /proc/net/dev"
        "cat /etc/netplan/50-cloud-init.yaml"
)

nic_commands=(
        "lspci | grep -i mell"
        "ibdev2netdev"
        "rdma dev"
        "ibv_devinfo"
        "ibstatus"
        "ibswitches"
        "ibhosts"
        "ibdump"
        "ibnodes"
        "ibstat -l"
        "ibnetdiscover"
        "iblinkinfo"
        "ibdiagnet -o /tmp/iboutput"
        "mst status"
        "rdma resource"
        "lshw -c network -businfo"
        "mstconfig q"
        "ofed_info"
        "lsmod | grep mlx"
        "cat /sys/class/net/*/mode"
        "systemctl status openibd.service"
        "systemctl status openibd"
)

misc_commands=(
        "history"
        "dmesg | grep -i mlx"
        "rocm-smi"
        "cat /opt/rocm/.info/version"
        "modinfo amdgpu | grep -i version"
        "amd-smi list"
)


execute_commands "${system_commands[@]}"
execute_commands "${network_commands[@]}"
execute_commands "${nic_commands[@]}"
execute_commands "${misc_commands[@]}"
check_nic_info ""
#mst_querry ""

## attach ibdiagnet files to the output file
cat /tmp/iboutput/* >> $OUTPUT_FILE
rm -rf /tmp/iboutput/*
echo "--------------- Collection Script Executed Successfully -----------"
echo "Output File saved to : " $(pwd)/$OUTPUT_FILE
