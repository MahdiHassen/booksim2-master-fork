#!/bin/zsh

# BookSim2 NoC Focused Simulation Script
# Real simulations with all required parameters

set -e

BOOKSIM_DIR="/Users/mahdi/Documents/booksim2-master"
SRC_DIR="${BOOKSIM_DIR}/src"
CONFIG_DIR="${BOOKSIM_DIR}/configs"
RESULTS_DIR="${BOOKSIM_DIR}/results"
BOOKSIM_EXE="${SRC_DIR}/booksim"

mkdir -p "${CONFIG_DIR}" "${RESULTS_DIR}"

# Clear results file and add header
echo "topology,k,n,nodes,traffic_pattern,injection_rate,num_vcs,avg_latency,avg_hops,throughput,energy_per_packet,simulation_time" > results/results.csv

echo "=== BookSim2 NoC Comprehensive Simulation ==="
echo "Running real simulations with full parameter sweep..."

# Function to create config and run simulation
run_simulation() {
    local k=$1
    local n=$2
    local nodes=$3
    local topo_name=$4
    local traffic=$5
    local rate=$6
    local vc=$7
    
    local config_file="${CONFIG_DIR}/sim_${topo_name}_${traffic}_${rate}_${vc}.txt"
    local output_file="${RESULTS_DIR}/out_${topo_name}_${traffic}_${rate}_${vc}.txt"
    
    # Create configuration
    cat > "${config_file}" << EOF
// BookSim2 Configuration
num_vcs = ${vc};
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
max_samples = 10;
topology = mesh;
k = ${k};
n = ${n};
routing_function = dor;
packet_size = 1;
use_read_write = 0;
traffic = ${traffic};
injection_rate = ${rate};
print_activity = 0;
print_csv_results = 1;
EOF

    echo -n "  ${topo_name} ${traffic} rate=${rate} vc=${vc} ... "
    
    # Run simulation with timeout
    if timeout 300 "${BOOKSIM_EXE}" "${config_file}" > "${output_file}" 2>&1; then
        # Check if simulation completed successfully
        if grep -q "Overall Traffic Statistics" "${output_file}"; then
            # Extract metrics
            local latency=$(grep -A 20 "Overall Traffic Statistics" "${output_file}" | grep "Packet latency average" | awk '{print $5}' | head -1)
            local hops=$(grep -A 20 "Overall Traffic Statistics" "${output_file}" | grep "Hops average" | awk '{print $4}' | head -1)
            local throughput=$(grep -A 20 "Overall Traffic Statistics" "${output_file}" | grep "Accepted packet rate average" | awk '{print $6}' | head -1)
            local sim_time=$(grep "Total run time" "${output_file}" | awk '{print $4}' | head -1)
            
            if [[ -n "$latency" && -n "$throughput" ]]; then
                echo "${topo_name},${k},${n},${nodes},${traffic},${rate},${vc},${latency},${hops:-N/A},${throughput},N/A,${sim_time:-N/A}" >> results/results.csv
                echo "✓ (${latency} cycles)"
                return 0
            fi
        fi
    fi
    
    echo "✗"
    echo "${topo_name},${k},${n},${nodes},${traffic},${rate},${vc},FAILED,N/A,N/A,N/A,N/A" >> results/results.csv
    return 1
}

# Counter for progress
total=0
completed=0
success=0

# Define simulation parameters
declare -a topologies=("2,2,4,2x2_torus" "4,2,16,4x4_torus" "8,2,64,8x8_torus")
declare -a patterns=("uniform" "transpose" "bitcomp" "bitrev" "shuffle")
declare -a rates=("0.1" "0.2" "0.3" "0.4" "0.5" "0.6" "0.7" "0.8" "0.9" "1.0")
declare -a vcs=("1" "2" "3")

# Calculate total simulations
total=$((${#topologies[@]} * ${#patterns[@]} * ${#rates[@]} * ${#vcs[@]}))

echo "Total simulations planned: ${total}"
echo ""

# Run all combinations
for topo_config in "${topologies[@]}"; do
    IFS=',' read -r k n nodes topo_name <<< "${topo_config}"
    echo "=== ${topo_name} (${k}-ary ${n}-cube, ${nodes} nodes) ==="
    
    for pattern in "${patterns[@]}"; do
        echo "Traffic: ${pattern}"
        
        for rate in "${rates[@]}"; do
            for vc in "${vcs[@]}"; do
                ((completed++))
                
                if run_simulation "$k" "$n" "$nodes" "$topo_name" "$pattern" "$rate" "$vc"; then
                    ((success++))
                fi
                
                # Progress indicator
                if (( completed % 10 == 0 )); then
                    echo "    Progress: ${completed}/${total} (${success} successful)"
                fi
            done
        done
    done
    echo ""
done

echo "=== Simulation Complete ==="
echo "Total: ${total}, Completed: ${completed}, Successful: ${success}"
echo "Results saved to: results/results.csv"
echo ""
echo "Sample results:"
head -5 results/results.csv
echo "..."
tail -3 results/results.csv
