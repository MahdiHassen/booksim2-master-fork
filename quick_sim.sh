#!/bin/zsh

# Quick manual simulation for key configurations
echo "Running key NoC simulations..."

# Helper function to run a single simulation
run_sim() {
    local k=$1
    local n=$2
    local nodes=$3
    local topo_name=$4
    local traffic=$5
    local rate=$6
    local vc=$7
    
    local config_file="configs/manual_${topo_name}_${traffic}_${rate}_${vc}.txt"
    local output_file="results/manual_${topo_name}_${traffic}_${rate}_${vc}.txt"
    
    # Create config
    cat > "${config_file}" << EOF
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
max_samples = 5;
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

    echo -n "Running ${topo_name} ${traffic} rate=${rate} vc=${vc}... "
    
    # Run simulation
    if timeout 60 ./src/booksim "${config_file}" > "${output_file}" 2>&1; then
        # Extract metrics
        local latency=$(grep -A 20 "Overall Traffic Statistics" "${output_file}" | grep "Packet latency average" | awk '{print $5}' | head -1)
        local hops=$(grep -A 20 "Overall Traffic Statistics" "${output_file}" | grep "Hops average" | awk '{print $4}' | head -1)
        local throughput=$(grep -A 20 "Overall Traffic Statistics" "${output_file}" | grep "Accepted packet rate average" | awk '{print $6}' | head -1)
        local sim_time=$(grep "Total run time" "${output_file}" | awk '{print $4}' | head -1)
        
        if [[ -n "$latency" && -n "$throughput" ]]; then
            echo "${topo_name},${k},${n},${nodes},${traffic},${rate},${vc},${latency},${hops},${throughput},N/A,${sim_time}" >> results/results.csv
            echo "✓ (latency: ${latency})"
        else
            echo "✗ (parse error)"
        fi
    else
        echo "✗ (timeout)"
    fi
}

# Key configurations to test
echo "Running representative simulations..."

# 2x2 torus
run_sim 2 2 4 "2x2_torus" "uniform" "0.05" 1
run_sim 2 2 4 "2x2_torus" "uniform" "0.1" 1
run_sim 2 2 4 "2x2_torus" "uniform" "0.15" 1
run_sim 2 2 4 "2x2_torus" "transpose" "0.05" 1
run_sim 2 2 4 "2x2_torus" "transpose" "0.1" 1
run_sim 2 2 4 "2x2_torus" "uniform" "0.05" 2
run_sim 2 2 4 "2x2_torus" "uniform" "0.05" 3

# 4x4 torus
run_sim 4 2 16 "4x4_torus" "uniform" "0.05" 1
run_sim 4 2 16 "4x4_torus" "uniform" "0.1" 1
run_sim 4 2 16 "4x4_torus" "uniform" "0.15" 1
run_sim 4 2 16 "4x4_torus" "transpose" "0.05" 1
run_sim 4 2 16 "4x4_torus" "transpose" "0.1" 1
run_sim 4 2 16 "4x4_torus" "uniform" "0.05" 2
run_sim 4 2 16 "4x4_torus" "uniform" "0.05" 3

# 8x8 torus
run_sim 8 2 64 "8x8_torus" "uniform" "0.05" 1
run_sim 8 2 64 "8x8_torus" "uniform" "0.1" 1
run_sim 8 2 64 "8x8_torus" "transpose" "0.05" 1
run_sim 8 2 64 "8x8_torus" "uniform" "0.05" 2

echo ""
echo "Simulation complete! Results:"
cat results/results.csv
