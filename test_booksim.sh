#!/bin/zsh

# BookSim2 NoC Simulation Script - Test Version
# Quick validation run with minimal configurations

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

# Test configurations - smaller subset
declare -a TOPOLOGIES=("2,2,4" "4,2,16")  # Only 2x2 and 4x4 for testing
declare -a TOPO_NAMES=("2x2_torus" "4x4_torus")

# Fewer traffic patterns for testing
declare -a TRAFFIC_PATTERNS=("uniform" "transpose")

# Fewer injection rates for testing
declare -a INJECTION_RATES=("0.05" "0.1" "0.15")

# Only 1 VC for testing
declare -a VCS=("1")

# Results file
RESULTS_CSV="${RESULTS_DIR}/test_results.csv"

# Initialize CSV header
echo "topology,k,n,nodes,traffic_pattern,injection_rate,num_vcs,avg_latency,avg_hops,throughput,energy_per_packet,simulation_time" > "${RESULTS_CSV}"

echo "=== BookSim2 NoC Test Simulation ==="
echo "Results will be saved to: ${RESULTS_CSV}"
echo ""

# Function to create config file
create_config_file() {
    local config_file="$1"
    local k="$2"
    local n="$3"
    local traffic="$4"
    local injection_rate="$5"
    local num_vcs="$6"
    
    cat > "${config_file}" << EOF
// BookSim2 Test Configuration for ${k}-ary ${n}-cube Torus
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

# Function to extract metrics from booksim output
extract_metrics() {
    local output_file="$1"
    local avg_latency=""
    local avg_hops=""
    local throughput=""
    local energy=""
    local sim_time=""
    
    # Extract from the final "Overall Traffic Statistics" section
    avg_latency=$(grep -A 20 "Overall Traffic Statistics" "${output_file}" | grep "Packet latency average" | awk '{print $5}' | head -1)
    
    # Extract average hops
    avg_hops=$(grep -A 20 "Overall Traffic Statistics" "${output_file}" | grep "Hops average" | awk '{print $4}' | head -1)
    
    # Extract throughput (accepted packets per cycle)
    throughput=$(grep -A 20 "Overall Traffic Statistics" "${output_file}" | grep "Accepted packet rate average" | awk '{print $6}' | head -1)
    
    # Extract simulation time
    sim_time=$(grep -E "Total run time" "${output_file}" | awk '{print $4}' | head -1)
    if [[ -z "${sim_time}" ]]; then
        sim_time="N/A"
    fi
    
    # Return values with defaults if not found
    echo "${avg_latency:-N/A},${avg_hops:-N/A},${throughput:-N/A},N/A,${sim_time:-N/A}"
}

# Main simulation loop
total_simulations=0
completed_simulations=0

# Calculate total simulations
for i in {1..${#TOPOLOGIES[@]}}; do
    for traffic in "${TRAFFIC_PATTERNS[@]}"; do
        for rate in "${INJECTION_RATES[@]}"; do
            for vc in "${VCS[@]}"; do
                ((total_simulations++))
            done
        done
    done
done

echo "Total test simulations to run: ${total_simulations}"
echo ""

# Run simulations
for i in {1..${#TOPOLOGIES[@]}}; do
    topo_config="${TOPOLOGIES[$i]}"
    topo_name="${TOPO_NAMES[$i]}"
    
    # Parse topology configuration
    IFS=',' read -r k n nodes <<< "${topo_config}"
    
    echo "=== Testing ${topo_name} (${k}-ary ${n}-cube, ${nodes} nodes) ==="
    
    for traffic in "${TRAFFIC_PATTERNS[@]}"; do
        echo "  Traffic pattern: ${traffic}"
        
        for rate in "${INJECTION_RATES[@]}"; do
            for vc in "${VCS[@]}"; do
                ((completed_simulations++))
                
                # Create unique config file name
                config_name="test_config_${topo_name}_${traffic}_rate${rate}_vc${vc}.txt"
                config_file="${CONFIG_DIR}/${config_name}"
                output_file="${RESULTS_DIR}/test_output_${topo_name}_${traffic}_rate${rate}_vc${vc}.txt"
                
                echo -n "    [${completed_simulations}/${total_simulations}] Rate: ${rate}, VCs: ${vc} ... "
                
                # Create config file
                create_config_file "${config_file}" "${k}" "${n}" "${traffic}" "${rate}" "${vc}"
                
                # Run simulation with timeout
                if timeout 60 "${BOOKSIM_EXE}" "${config_file}" > "${output_file}" 2>&1; then
                    # Extract metrics
                    metrics=$(extract_metrics "${output_file}")
                    
                    # Write to CSV
                    echo "${topo_name},${k},${n},${nodes},${traffic},${rate},${vc},${metrics}" >> "${RESULTS_CSV}"
                    
                    echo "✓"
                else
                    # Simulation failed or timed out
                    echo "${topo_name},${k},${n},${nodes},${traffic},${rate},${vc},TIMEOUT,N/A,N/A,N/A,N/A" >> "${RESULTS_CSV}"
                    echo "✗ (timeout/error)"
                fi
            done
        done
    done
    echo ""
done

echo "=== Test Simulation Complete ==="
echo "Results saved to: ${RESULTS_CSV}"
echo "Total simulations: ${total_simulations}"
echo ""
echo "Test results:"
cat "${RESULTS_CSV}"
