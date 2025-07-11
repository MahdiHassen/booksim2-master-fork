#!/bin/zsh

# BookSim2 NoC Simulation Script
# Evaluates torus topology with varying system sizes, traffic patterns, injection rates, and VCs

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

# System configurations (k-ary n-cube: k=radix, n=dimensions)
declare -a TOPOLOGIES=("2,2,4" "4,2,16" "8,2,64")  # k,n,nodes format
declare -a TOPO_NAMES=("2x2_torus" "4x4_torus" "8x8_torus")

# Traffic patterns for synthetic evaluation (patterns that work without extra parameters)
declare -a TRAFFIC_PATTERNS=("uniform" "transpose" "bitcomp" "bitrev" "shuffle")

# Injection rates (0.1, 0.2, ..., 0.9, 1.0)
declare -a INJECTION_RATES=("0.1" "0.2" "0.3" "0.4" "0.5" "0.6" "0.7" "0.8" "0.9" "1.0")

# Virtual channels
declare -a VCS=("1" "2" "3")

# Results file
RESULTS_CSV="${RESULTS_DIR}/results.csv"

# Initialize CSV header
echo "topology,k,n,nodes,traffic_pattern,injection_rate,num_vcs,avg_latency,avg_hops,throughput,energy_per_packet,simulation_time" > "${RESULTS_CSV}"

echo "=== BookSim2 NoC Simulation Suite ==="
echo "Results will be saved to: ${RESULTS_CSV}"
echo "Config files directory: ${CONFIG_DIR}"
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
// BookSim2 Configuration for ${k}-ary ${n}-cube Torus
// Traffic: ${traffic}, Injection Rate: ${injection_rate}, VCs: ${num_vcs}

// Flow control
num_vcs = ${num_vcs};
vc_buf_size = 8;
wait_for_tail_credit = 1;

// Allocators
vc_allocator = islip;
sw_allocator = islip;
alloc_iters = 2;

// Timing
credit_delay = 2;
routing_delay = 0;
vc_alloc_delay = 1;
sw_alloc_delay = 1;
st_final_delay = 1;

// Speedup
input_speedup = 1;
output_speedup = 1;
internal_speedup = 1.0;

// Simulation
sim_type = latency;
warmup_periods = 3;
sample_period = 1000;
sim_count = 1;
max_samples = 3;

// Topology
topology = mesh;  // mesh with wraparound = torus
k = ${k};
n = ${n};

// Routing
routing_function = dor;

// Traffic
packet_size = 1;
use_read_write = 0;
traffic = ${traffic};
injection_rate = ${injection_rate};

// Output
print_activity = 0;
print_csv_results = 1;
EOF
}

# Function to extract metrics from booksim output
extract_metrics() {
    local output_file="$1"
    
    # Check if simulation completed successfully
    if ! grep -q "Overall Traffic Statistics" "${output_file}"; then
        echo "ERROR,N/A,N/A,N/A,N/A"
        return 1
    fi
    
    # Extract from the final "Overall Traffic Statistics" section
    local avg_latency=$(grep -A 20 "Overall Traffic Statistics" "${output_file}" | grep "Packet latency average" | awk '{print $5}' | head -1)
    local avg_hops=$(grep -A 20 "Overall Traffic Statistics" "${output_file}" | grep "Hops average" | awk '{print $4}' | head -1)
    local throughput=$(grep -A 20 "Overall Traffic Statistics" "${output_file}" | grep "Accepted packet rate average" | awk '{print $6}' | head -1)
    local sim_time=$(grep -E "Total run time" "${output_file}" | awk '{print $4}' | head -1)
    
    # Return values with defaults if not found
    echo "${avg_latency:-N/A},${avg_hops:-N/A},${throughput:-N/A},N/A,${sim_time:-N/A}"
    return 0
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

echo "Total simulations to run: ${total_simulations}"
echo ""

# Run simulations
for i in {1..${#TOPOLOGIES[@]}}; do
    topo_config="${TOPOLOGIES[$i]}"
    topo_name="${TOPO_NAMES[$i]}"
    
    # Parse topology configuration
    IFS=',' read -r k n nodes <<< "${topo_config}"
    
    echo "=== Running simulations for ${topo_name} (${k}-ary ${n}-cube, ${nodes} nodes) ==="
    
    for traffic in "${TRAFFIC_PATTERNS[@]}"; do
        echo "  Traffic pattern: ${traffic}"
        
        for rate in "${INJECTION_RATES[@]}"; do
            for vc in "${VCS[@]}"; do
                ((completed_simulations++))
                
                # Create unique config file name
                config_name="config_${topo_name}_${traffic}_rate${rate}_vc${vc}.txt"
                config_file="${CONFIG_DIR}/${config_name}"
                output_file="${RESULTS_DIR}/output_${topo_name}_${traffic}_rate${rate}_vc${vc}.txt"
                
                echo -n "    [${completed_simulations}/${total_simulations}] Rate: ${rate}, VCs: ${vc} ... "
                
                # Create config file
                create_config_file "${config_file}" "${k}" "${n}" "${traffic}" "${rate}" "${vc}"
                
                # Run simulation without timeout
                if "${BOOKSIM_EXE}" "${config_file}" > "${output_file}" 2>&1; then
                    # Extract metrics
                    if metrics=$(extract_metrics "${output_file}"); then
                        # Check if extraction was successful
                        if [[ "${metrics}" != ERROR* ]]; then
                            echo "${topo_name},${k},${n},${nodes},${traffic},${rate},${vc},${metrics}" >> "${RESULTS_CSV}"
                            echo "✓"
                        else
                            echo "${topo_name},${k},${n},${nodes},${traffic},${rate},${vc},PARSE_ERROR,N/A,N/A,N/A,N/A" >> "${RESULTS_CSV}"
                            echo "✗ (parse error)"
                        fi
                    else
                        echo "${topo_name},${k},${n},${nodes},${traffic},${rate},${vc},EXTRACT_ERROR,N/A,N/A,N/A,N/A" >> "${RESULTS_CSV}"
                        echo "✗ (extraction failed)"
                    fi
                else
                    # Simulation failed or timed out
                    echo "${topo_name},${k},${n},${nodes},${traffic},${rate},${vc},TIMEOUT,N/A,N/A,N/A,N/A" >> "${RESULTS_CSV}"
                    echo "✗ (timeout/error)"
                fi
                
                # Clean up large output files to save space
                if [[ -f "${output_file}" ]] && [[ $(wc -c < "${output_file}") -gt 500000 ]]; then
                    rm "${output_file}"
                fi
            done
        done
    done
    echo ""
done

echo "=== Simulation Complete ==="
echo "Results saved to: ${RESULTS_CSV}"
echo "Total simulations: ${total_simulations}"
echo "Check the results.csv file for detailed metrics."
echo ""
echo "Next steps:"
echo "1. Run: python3 plot_results.py to generate visualization"
echo "2. View the generated plot.png file"
