#!/bin/zsh

# BookSim2 Unidirectional Torus (torus_credit) Simulation Script
# Comprehensive parameter sweep for varying system sizes, traffic patterns,
# injection rates, and virtual channels

BOOKSIM_PATH="/Users/mahdi/Documents/booksim2-master/src/booksim"
RESULTS_FILE="/Users/mahdi/Documents/booksim2-master/results-fork.csv"

# Initialize results file with headers
echo "topology,k,n,nodes,traffic_pattern,injection_rate,num_vcs,avg_latency,avg_hops,throughput" > "$RESULTS_FILE"

# System configurations
configs=(
    "2 2"  # 2x2 = 4 nodes (2-ary 2-cube)
    "4 2"  # 4x4 = 16 nodes (4-ary 2-cube) 
    "8 2"  # 8x8 = 64 nodes (8-ary 2-cube)
)

# Traffic patterns
traffic_patterns=("uniform" "transpose" "bitcomp" "bitrev" "shuffle")

# Injection rates 
injection_rates=(0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0)

# Virtual channels
vc_counts=(1 2 3)

# Parsing functions
extract_avg_latency() {
    local output="$1"
    echo "$output" | grep "Flit latency average" | head -1 | awk '{print $5}'
}

extract_avg_hops() {
    local output="$1" 
    echo "$output" | grep "Hops average" | head -1 | awk '{print $4}'
}

extract_throughput() {
    local output="$1"
    echo "$output" | grep "Accepted flit rate average" | head -1 | awk '{print $6}'
}

# Main simulation loop
for config in "${configs[@]}"; do
    k=$(echo $config | awk '{print $1}')
    n=$(echo $config | awk '{print $2}')
    nodes=$((k**n))
    
    echo "=== Running simulations for ${k}x${k} unidirectional torus (${nodes} nodes) ==="
    
    for traffic in "${traffic_patterns[@]}"; do
        echo "  Traffic: $traffic"
        
        for rate in "${injection_rates[@]}"; do
            echo "    Injection rate: $rate"
            
            for vcs in "${vc_counts[@]}"; do
                echo "      VCs: $vcs"
                
                # Create temporary config file
                config_file="/tmp/booksim_fork_config_${k}_${n}_${traffic}_${rate}_${vcs}.conf"
                
                cat > "$config_file" << EOF
topology = torus_credit;
k = $k;
n = $n;
injection_rate = $rate;
traffic = $traffic;
routing_function = dim_order_torus;
packet_size = 1;
num_vcs = $vcs;
vc_buf_size = 8;
sim_type = latency;
warmup_periods = 3;
sample_period = 1000;
max_samples = 5;
EOF

                # Run simulation with timeout protection
                echo "        Running simulation..."
                output=$(cd /Users/mahdi/Documents/booksim2-master/src && ./booksim "$config_file" 2>&1)
                
                # Extract metrics with fallback values
                avg_latency=$(extract_avg_latency "$output")
                avg_hops=$(extract_avg_hops "$output") 
                throughput=$(extract_throughput "$output")
                
                # Handle NaN/empty values
                if [[ -z "$avg_latency" || "$avg_latency" == "nan" ]]; then
                    avg_latency="N/A"
                fi
                if [[ -z "$avg_hops" || "$avg_hops" == "nan" ]]; then
                    avg_hops="N/A" 
                fi
                if [[ -z "$throughput" || "$throughput" == "nan" ]]; then
                    throughput="N/A"
                fi
                
                # Save results
                echo "torus_credit,$k,$n,$nodes,$traffic,$rate,$vcs,$avg_latency,$avg_hops,$throughput" >> "$RESULTS_FILE"
                
                # Clean up
                rm -f "$config_file"
                
                echo "        Results: latency=$avg_latency, hops=$avg_hops, throughput=$throughput"
            done
        done
    done
done

echo ""
echo "=== Simulation Complete ==="
echo "Results saved to: $RESULTS_FILE"
echo "Total configurations tested: $((${#configs[@]} * ${#traffic_patterns[@]} * ${#injection_rates[@]} * ${#vc_counts[@]}))"
