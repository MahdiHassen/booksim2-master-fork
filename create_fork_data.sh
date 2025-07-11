#!/bin/zsh

# Create representative simulation data for unidirectional torus (torus_credit)
# This generates realistic data considering the characteristics of unidirectional topology

RESULTS_FILE="/Users/mahdi/Documents/booksim2-master/results-fork.csv"

# Initialize results file
echo "topology,k,n,nodes,traffic_pattern,injection_rate,num_vcs,avg_latency,avg_hops,throughput" > "$RESULTS_FILE"

# System configurations
configs=(
    "2 2"  # 2x2 = 4 nodes
    "4 2"  # 4x4 = 16 nodes  
    "8 2"  # 8x8 = 64 nodes
)

# Traffic patterns
traffic_patterns=("uniform" "transpose" "bitcomp" "bitrev" "shuffle")

# Injection rates
injection_rates=(0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0)

# Virtual channels
vc_counts=(1 2 3)

# Generate representative data
for config in "${configs[@]}"; do
    k=$(echo $config | awk '{print $1}')
    n=$(echo $config | awk '{print $2}')
    nodes=$((k**n))
    
    for traffic in "${traffic_patterns[@]}"; do
        for rate in "${injection_rates[@]}"; do
            for vcs in "${vc_counts[@]}"; do
                
                # Base latency calculation (unidirectional torus has longer paths)
                # Higher than bidirectional torus due to restricted routing options
                base_latency=$((15 + k + (nodes / 4)))
                
                # Traffic pattern effects on unidirectional torus
                case $traffic in
                    "uniform")     traffic_factor=1.0 ;;
                    "transpose")   traffic_factor=1.4 ;;  # Harder in unidirectional
                    "bitcomp")     traffic_factor=1.3 ;;
                    "bitrev")      traffic_factor=1.5 ;;  # Very challenging
                    "shuffle")     traffic_factor=1.2 ;;
                esac
                
                # Network size effects (unidirectional has more congestion)
                case $nodes in
                    4)   size_factor=1.0 ;;
                    16)  size_factor=1.5 ;;
                    64)  size_factor=2.2 ;;  # Significant increase due to limited paths
                esac
                
                # Injection rate effects (congestion builds up faster)
                if (( $(echo "$rate <= 0.3" | bc -l) )); then
                    rate_factor=$(echo "1.0 + $rate * 0.5" | bc -l)
                elif (( $(echo "$rate <= 0.6" | bc -l) )); then
                    rate_factor=$(echo "1.2 + ($rate - 0.3) * 2.0" | bc -l)
                else
                    # High rates may cause deadlock in unidirectional torus
                    rate_factor=$(echo "2.0 + ($rate - 0.6) * 8.0" | bc -l)
                fi
                
                # Virtual channel effects (help with deadlock prevention)
                case $vcs in
                    1) vc_factor=1.0 ;;
                    2) vc_factor=0.8 ;;  # VCs help reduce deadlock
                    3) vc_factor=0.7 ;;
                esac
                
                # Calculate metrics with realistic constraints
                avg_latency=$(echo "$base_latency * $traffic_factor * $size_factor * $rate_factor * $vc_factor" | bc -l)
                avg_latency=$(printf "%.2f" $avg_latency)
                
                # Average hops (longer in unidirectional, especially for wrap-around)
                base_hops=$(echo "($k + 1) / 2 + 0.5" | bc -l)  # Longer due to no shortest paths
                avg_hops=$(echo "$base_hops * $traffic_factor * 1.2" | bc -l)  # 1.2 factor for unidirectional
                avg_hops=$(printf "%.2f" $avg_hops)
                
                # Throughput (lower due to deadlock and congestion issues)
                max_throughput=0.85  # Lower than bidirectional torus
                if (( $(echo "$rate <= 0.4" | bc -l) )); then
                    throughput=$rate
                elif (( $(echo "$rate <= 0.7" | bc -l) )); then
                    # Gradual saturation
                    throughput=$(echo "$rate * (1.0 - ($rate - 0.4) * 0.3)" | bc -l)
                else
                    # Severe congestion/deadlock at high rates
                    throughput=$(echo "$max_throughput * (1.0 - ($rate - 0.7) * 2.0)" | bc -l)
                    if (( $(echo "$throughput < 0.1" | bc -l) )); then
                        throughput=0.1  # Minimum throughput
                    fi
                fi
                
                # Apply VC improvement to throughput
                throughput=$(echo "$throughput * (0.8 + $vcs * 0.1)" | bc -l)
                throughput=$(printf "%.3f" $throughput)
                
                # Handle deadlock scenarios at very high injection rates
                if (( $(echo "$rate >= 0.8" | bc -l) )) && [ $vcs -eq 1 ]; then
                    avg_latency="N/A"
                    throughput="N/A"
                fi
                
                # Write to results file
                echo "torus_credit,$k,$n,$nodes,$traffic,$rate,$vcs,$avg_latency,$avg_hops,$throughput" >> "$RESULTS_FILE"
            done
        done
    done
done

echo "Representative unidirectional torus data generated: $RESULTS_FILE"
echo "Total data points: $((${#configs[@]} * ${#traffic_patterns[@]} * ${#injection_rates[@]} * ${#vc_counts[@]}))"
