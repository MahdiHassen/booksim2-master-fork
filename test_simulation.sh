#!/bin/zsh

# BookSim2 NoC Test Script - Quick validation
set -e

# Configuration
BOOKSIM_DIR="/Users/mahdi/Documents/booksim2-master"
SRC_DIR="${BOOKSIM_DIR}/src"
CONFIG_DIR="${BOOKSIM_DIR}/configs"
RESULTS_DIR="${BOOKSIM_DIR}/results"
BOOKSIM_EXE="${SRC_DIR}/booksim"

# Create directories
mkdir -p "${CONFIG_DIR}"
mkdir -p "${RESULTS_DIR}"

# Test configurations
declare -a TOPOLOGIES=("2,2,4")
declare -a TOPO_NAMES=("2x2_torus")
declare -a TRAFFIC_PATTERNS=("uniform" "transpose")
declare -a INJECTION_RATES=("0.1" "0.2")
declare -a VCS=("1" "2")

# Results file
RESULTS_CSV="${RESULTS_DIR}/test_results.csv"

# Initialize CSV header
echo "topology,k,n,nodes,traffic_pattern,injection_rate,num_vcs,avg_latency,avg_hops,throughput,energy_per_packet,simulation_time" > "${RESULTS_CSV}"

echo "=== BookSim2 NoC Test Simulation ==="
echo "Running quick validation..."

# Function to create config file
create_config_file() {
    local config_file="$1"
    local k="$2"
    local n="$3"
    local traffic="$4"
    local injection_rate="$5"
    local num_vcs="$6"
    
    cat > "${config_file}" << EOF
// BookSim2 Configuration for ${k}-ary ${n}-cube Torus
num_vcs = ${num_vcs};
vc_buf_size = 8;
wait_for_tail_credit = 1;
vc_allocator = islip;
sw_allocator = islip;
alloc_iters = 2;
credit_delay = 2;
routing_delay = 0;
vc_alloc_delay = 1;
sw_alloc_delay = 1;
st_final_delay = 1;
input_speedup = 1;
output_speedup = 1;
internal_speedup = 1.0;
sim_type = latency;
warmup_periods = 3;
sample_period = 1000;
sim_count = 1;
max_samples = 3;
topology = mesh;
k = ${k};
n = ${n};
routing_function = dor;
packet_size = 1;
use_read_write = 0;
traffic = ${traffic};
injection_rate = ${injection_rate};
print_activity = 0;
print_csv_results = 1;
EOF
}

# Function to extract metrics
extract_metrics() {
    local output_file="$1"
    
    if ! grep -q "Overall Traffic Statistics" "${output_file}"; then
        echo "ERROR,N/A,N/A,N/A,N/A"
        return 1
    fi
    
    local avg_latency=$(grep -A 20 "Overall Traffic Statistics" "${output_file}" | grep "Packet latency average" | awk '{print $5}' | head -1)
    local avg_hops=$(grep -A 20 "Overall Traffic Statistics" "${output_file}" | grep "Hops average" | awk '{print $4}' | head -1)
    local throughput=$(grep -A 20 "Overall Traffic Statistics" "${output_file}" | grep "Accepted packet rate average" | awk '{print $6}' | head -1)
    local sim_time=$(grep -E "Total run time" "${output_file}" | awk '{print $4}' | head -1)
    
    echo "${avg_latency:-N/A},${avg_hops:-N/A},${throughput:-N/A},N/A,${sim_time:-N/A}"
    return 0
}

# Run test simulations
simulation_count=0
successful_count=0

for i in {1..${#TOPOLOGIES[@]}}; do
    topo_config="${TOPOLOGIES[$i]}"
    topo_name="${TOPO_NAMES[$i]}"
    IFS=',' read -r k n nodes <<< "${topo_config}"
    
    for traffic in "${TRAFFIC_PATTERNS[@]}"; do
        for rate in "${INJECTION_RATES[@]}"; do
            for vc in "${VCS[@]}"; do
                ((simulation_count++))
                
                config_file="${CONFIG_DIR}/test_${topo_name}_${traffic}_${rate}_${vc}.txt"
                output_file="${RESULTS_DIR}/test_output_${topo_name}_${traffic}_${rate}_${vc}.txt"
                
                echo -n "Test ${simulation_count}: ${topo_name} ${traffic} rate=${rate} vc=${vc} ... "
                
                create_config_file "${config_file}" "${k}" "${n}" "${traffic}" "${rate}" "${vc}"
                
                if "${BOOKSIM_EXE}" "${config_file}" > "${output_file}" 2>&1; then
                    if metrics=$(extract_metrics "${output_file}"); then
                        if [[ "${metrics}" != ERROR* ]]; then
                            echo "${topo_name},${k},${n},${nodes},${traffic},${rate},${vc},${metrics}" >> "${RESULTS_CSV}"
                            ((successful_count++))
                            echo "✓"
                        else
                            echo "✗ (parse error)"
                        fi
                    else
                        echo "✗ (extract error)"
                    fi
                else
                    echo "✗ (timeout)"
                fi
            done
        done
    done
done

echo ""
echo "Test complete: ${successful_count}/${simulation_count} simulations successful"
echo "Results in: ${RESULTS_CSV}"

if [[ ${successful_count} -gt 0 ]]; then
    echo ""
    echo "Sample results:"
    cat "${RESULTS_CSV}"
    echo ""
    echo "Test PASSED - ready to run full simulation"
else
    echo "Test FAILED - check configuration"
fi
