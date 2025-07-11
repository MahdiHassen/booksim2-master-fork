#!/usr/bin/env python3

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
from pathlib import Path

def create_latency_throughput_analysis():
    """
    Creates comprehensive visualization for BookSim2 unidirectional torus (torus_credit) simulation results
    """
    
    # Read the results
    results_path = "/Users/mahdi/Documents/booksim2-master/results-fork.csv"
    df = pd.read_csv(results_path)
    
    # Convert N/A values to NaN for proper handling
    df['avg_latency'] = pd.to_numeric(df['avg_latency'], errors='coerce')
    df['throughput'] = pd.to_numeric(df['throughput'], errors='coerce')
    df['avg_hops'] = pd.to_numeric(df['avg_hops'], errors='coerce')
    
    # Create the comprehensive plot
    fig, axes = plt.subplots(3, 3, figsize=(20, 16))
    fig.suptitle('BookSim2 Unidirectional Torus (torus_credit) NoC Performance Analysis\n'
                 'System Sizes: 2x2, 4x4, 8x8 | Traffic: Uniform, Transpose, BitComp, BitRev, Shuffle | VCs: 1,2,3',
                 fontsize=16, fontweight='bold')
    
    # Color schemes
    colors = sns.color_palette("husl", 3)  # For different k values
    traffic_colors = sns.color_palette("Set2", 5)  # For traffic patterns
    
    # 1. Latency vs Injection Rate by System Size (Row 1, Col 1)
    ax1 = axes[0, 0]
    for i, k in enumerate([2, 4, 8]):
        subset = df[(df['k'] == k) & (df['traffic_pattern'] == 'uniform') & (df['num_vcs'] == 2)]
        subset_clean = subset.dropna(subset=['avg_latency'])
        ax1.plot(subset_clean['injection_rate'], subset_clean['avg_latency'], 
                marker='o', linewidth=2, markersize=6, color=colors[i], 
                label=f'{k}x{k} ({k**2} nodes)')
    ax1.set_xlabel('Injection Rate')
    ax1.set_ylabel('Average Latency (cycles)')
    ax1.set_title('Latency vs Injection Rate\n(Uniform Traffic, 2 VCs)')
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    
    # 2. Throughput vs Injection Rate by System Size (Row 1, Col 2)
    ax2 = axes[0, 1]
    for i, k in enumerate([2, 4, 8]):
        subset = df[(df['k'] == k) & (df['traffic_pattern'] == 'uniform') & (df['num_vcs'] == 2)]
        subset_clean = subset.dropna(subset=['throughput'])
        ax2.plot(subset_clean['injection_rate'], subset_clean['throughput'], 
                marker='s', linewidth=2, markersize=6, color=colors[i], 
                label=f'{k}x{k} ({k**2} nodes)')
    ax2.set_xlabel('Injection Rate')
    ax2.set_ylabel('Throughput (flits/cycle/node)')
    ax2.set_title('Throughput vs Injection Rate\n(Uniform Traffic, 2 VCs)')
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    
    # 3. Traffic Pattern Comparison - Average Latency Heatmap (Row 1, Col 3)
    ax3 = axes[0, 2]
    pivot_data = df.groupby(['traffic_pattern', 'k'])['avg_latency'].mean().unstack()
    pivot_data_clean = pivot_data.fillna(0)  # Fill NaN with 0 for visualization
    sns.heatmap(pivot_data_clean, annot=True, fmt='.1f', cmap='YlOrRd', ax=ax3)
    ax3.set_title('Average Latency by Traffic Pattern\n(All injection rates, 2 VCs)')
    ax3.set_xlabel('System Size (k)')
    ax3.set_ylabel('Traffic Pattern')
    
    # 4. Virtual Channel Efficiency - Latency (Row 2, Col 1)
    ax4 = axes[1, 0]
    k_val = 4  # Focus on 4x4 for VC analysis
    for i, traffic in enumerate(['uniform', 'transpose', 'bitcomp']):
        subset = df[(df['k'] == k_val) & (df['traffic_pattern'] == traffic) & (df['injection_rate'] == 0.5)]
        subset_clean = subset.dropna(subset=['avg_latency'])
        if not subset_clean.empty:
            ax4.bar([i*3 + j for j in range(3)], subset_clean['avg_latency'], 
                   color=[plt.cm.viridis(0.3), plt.cm.viridis(0.6), plt.cm.viridis(0.9)],
                   alpha=0.8, width=0.8)
    
    ax4.set_xlabel('Configuration')
    ax4.set_ylabel('Average Latency (cycles)')
    ax4.set_title(f'Virtual Channel Impact on Latency\n({k_val}x{k_val} torus, rate=0.5)')
    ax4.set_xticks([1, 4, 7])
    ax4.set_xticklabels(['Uniform', 'Transpose', 'BitComp'])
    
    # Add VC legend
    from matplotlib.patches import Patch
    legend_elements = [Patch(facecolor=plt.cm.viridis(0.3), label='1 VC'),
                      Patch(facecolor=plt.cm.viridis(0.6), label='2 VCs'),
                      Patch(facecolor=plt.cm.viridis(0.9), label='3 VCs')]
    ax4.legend(handles=legend_elements, loc='upper left')
    ax4.grid(True, alpha=0.3)
    
    # 5. Average Hops vs System Size (Row 2, Col 2)
    ax5 = axes[1, 1]
    for i, traffic in enumerate(['uniform', 'transpose', 'bitrev']):
        subset = df[(df['traffic_pattern'] == traffic) & (df['num_vcs'] == 2) & (df['injection_rate'] == 0.3)]
        subset_clean = subset.dropna(subset=['avg_hops'])
        if not subset_clean.empty:
            ax5.plot(subset_clean['k'], subset_clean['avg_hops'], 
                    marker='o', linewidth=2, markersize=8, 
                    color=traffic_colors[i], label=traffic.capitalize())
    ax5.set_xlabel('System Size (k)')
    ax5.set_ylabel('Average Hops')
    ax5.set_title('Average Hops vs System Size\n(Various Traffic, rate=0.3, 2 VCs)')
    ax5.legend()
    ax5.grid(True, alpha=0.3)
    
    # 6. Scalability Analysis (Row 2, Col 3)
    ax6 = axes[1, 2]
    scalability_data = []
    for k in [2, 4, 8]:
        nodes = k**2
        subset = df[(df['k'] == k) & (df['traffic_pattern'] == 'uniform') & 
                   (df['num_vcs'] == 2) & (df['injection_rate'] == 0.4)]
        subset_clean = subset.dropna(subset=['avg_latency', 'throughput'])
        if not subset_clean.empty:
            latency = subset_clean['avg_latency'].iloc[0]
            throughput = subset_clean['throughput'].iloc[0]
            scalability_data.append([nodes, latency, throughput])
    
    if scalability_data:
        scalability_df = pd.DataFrame(scalability_data, columns=['nodes', 'latency', 'throughput'])
        ax6_twin = ax6.twinx()
        
        bars1 = ax6.bar(scalability_df['nodes'], scalability_df['latency'], 
                       alpha=0.7, color='steelblue', label='Latency')
        line1 = ax6_twin.plot(scalability_df['nodes'], scalability_df['throughput'], 
                             'ro-', linewidth=2, markersize=8, label='Throughput')
        
        ax6.set_xlabel('Number of Nodes')
        ax6.set_ylabel('Average Latency (cycles)', color='steelblue')
        ax6_twin.set_ylabel('Throughput (flits/cycle/node)', color='red')
        ax6.set_title('Scalability Analysis\n(Uniform, rate=0.4, 2 VCs)')
        
        # Combined legend
        lines1, labels1 = ax6.get_legend_handles_labels()
        lines2, labels2 = ax6_twin.get_legend_handles_labels()
        ax6.legend(lines1 + lines2, labels1 + labels2, loc='upper left')
    
    ax6.grid(True, alpha=0.3)
    
    # 7. Deadlock Analysis - Failed Simulations (Row 3, Col 1)
    ax7 = axes[2, 0]
    # Count N/A entries (indicating deadlock/failure) by injection rate and VC count
    deadlock_data = []
    for rate in df['injection_rate'].unique():
        for vcs in [1, 2, 3]:
            subset = df[(df['injection_rate'] == rate) & (df['num_vcs'] == vcs)]
            total_sims = len(subset)
            failed_sims = subset['avg_latency'].isna().sum()
            failure_rate = failed_sims / total_sims if total_sims > 0 else 0
            deadlock_data.append([rate, vcs, failure_rate])
    
    deadlock_df = pd.DataFrame(deadlock_data, columns=['injection_rate', 'num_vcs', 'failure_rate'])
    pivot_deadlock = deadlock_df.pivot(index='injection_rate', columns='num_vcs', values='failure_rate')
    
    sns.heatmap(pivot_deadlock, annot=True, fmt='.2f', cmap='Reds', ax=ax7)
    ax7.set_title('Deadlock/Failure Rate Analysis\n(Unidirectional Torus Limitations)')
    ax7.set_xlabel('Number of Virtual Channels')
    ax7.set_ylabel('Injection Rate')
    
    # 8. Performance Comparison Matrix (Row 3, Col 2)
    ax8 = axes[2, 1]
    # Create performance score (inverse latency * throughput)
    df_perf = df.copy()
    df_perf = df_perf.dropna(subset=['avg_latency', 'throughput'])
    df_perf['performance_score'] = df_perf['throughput'] / (df_perf['avg_latency'] / 100)  # Normalized
    
    perf_pivot = df_perf.groupby(['k', 'num_vcs'])['performance_score'].mean().unstack()
    sns.heatmap(perf_pivot, annot=True, fmt='.3f', cmap='viridis', ax=ax8)
    ax8.set_title('Performance Score Matrix\n(Throughput/Latency Ratio)')
    ax8.set_xlabel('Number of Virtual Channels')
    ax8.set_ylabel('System Size (k)')
    
    # 9. Traffic Pattern Impact Summary (Row 3, Col 3)
    ax9 = axes[2, 2]
    # Calculate relative performance compared to uniform traffic
    uniform_baseline = df[(df['traffic_pattern'] == 'uniform') & (df['k'] == 4) & 
                         (df['num_vcs'] == 2) & (df['injection_rate'] == 0.4)]
    
    if not uniform_baseline.empty:
        baseline_latency = uniform_baseline['avg_latency'].iloc[0]
        baseline_throughput = uniform_baseline['throughput'].iloc[0]
        
        traffic_comparison = []
        for traffic in df['traffic_pattern'].unique():
            subset = df[(df['traffic_pattern'] == traffic) & (df['k'] == 4) & 
                       (df['num_vcs'] == 2) & (df['injection_rate'] == 0.4)]
            subset_clean = subset.dropna(subset=['avg_latency', 'throughput'])
            if not subset_clean.empty:
                rel_latency = subset_clean['avg_latency'].iloc[0] / baseline_latency
                rel_throughput = subset_clean['throughput'].iloc[0] / baseline_throughput
                traffic_comparison.append([traffic, rel_latency, rel_throughput])
        
        if traffic_comparison:
            traffic_df = pd.DataFrame(traffic_comparison, columns=['traffic', 'rel_latency', 'rel_throughput'])
            
            x = np.arange(len(traffic_df))
            width = 0.35
            
            bars1 = ax9.bar(x - width/2, traffic_df['rel_latency'], width, 
                           label='Relative Latency', alpha=0.8, color='lightcoral')
            bars2 = ax9.bar(x + width/2, traffic_df['rel_throughput'], width, 
                           label='Relative Throughput', alpha=0.8, color='skyblue')
            
            ax9.axhline(y=1.0, color='black', linestyle='--', alpha=0.5, label='Uniform Baseline')
            ax9.set_xlabel('Traffic Pattern')
            ax9.set_ylabel('Relative Performance')
            ax9.set_title('Traffic Pattern Impact\n(Relative to Uniform, 4x4, rate=0.4)')
            ax9.set_xticks(x)
            ax9.set_xticklabels(traffic_df['traffic'], rotation=45)
            ax9.legend()
            ax9.grid(True, alpha=0.3)
    
    plt.tight_layout()
    
    # Save the plot
    output_path = "/Users/mahdi/Documents/booksim2-master/plot-fork.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"Comprehensive unidirectional torus analysis saved to: {output_path}")
    
    # Print summary statistics
    print("\n=== Unidirectional Torus Performance Summary ===")
    total_configs = len(df)
    failed_configs = df['avg_latency'].isna().sum()
    print(f"Total configurations: {total_configs}")
    print(f"Failed simulations (deadlock): {failed_configs} ({failed_configs/total_configs*100:.1f}%)")
    
    # Best performing configurations
    df_clean = df.dropna(subset=['avg_latency', 'throughput'])
    if not df_clean.empty:
        df_clean['efficiency'] = df_clean['throughput'] / df_clean['avg_latency']
        best_config = df_clean.loc[df_clean['efficiency'].idxmax()]
        print(f"\nBest efficiency configuration:")
        print(f"  System: {best_config['k']}x{best_config['k']} ({best_config['nodes']} nodes)")
        print(f"  Traffic: {best_config['traffic_pattern']}")
        print(f"  Injection rate: {best_config['injection_rate']}")
        print(f"  VCs: {best_config['num_vcs']}")
        print(f"  Latency: {best_config['avg_latency']:.2f} cycles")
        print(f"  Throughput: {best_config['throughput']:.3f} flits/cycle/node")

if __name__ == "__main__":
    create_latency_throughput_analysis()
