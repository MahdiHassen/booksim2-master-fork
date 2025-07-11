#!/usr/bin/env python3

"""
BookSim2 Results Visualization Script
Creates comprehensive plots for NoC simulation results
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
from matplotlib.patches import Rectangle
import warnings
warnings.filterwarnings('ignore')

# Set style for professional-looking plots
plt.style.use('seaborn-v0_8-darkgrid')
sns.set_palette("husl")

def load_and_clean_data(csv_file):
    """Load and clean the simulation results"""
    try:
        df = pd.read_csv(csv_file)
        # Convert numeric columns
        numeric_cols = ['injection_rate', 'num_vcs', 'avg_latency', 'avg_hops', 'throughput']
        for col in numeric_cols:
            if col in df.columns:
                df[col] = pd.to_numeric(df[col], errors='coerce')
        
        # Remove timeout/error rows
        df = df[df['avg_latency'] != 'TIMEOUT']
        df = df[df['avg_latency'] != 'N/A']
        df = df.dropna(subset=['avg_latency', 'throughput'])
        
        return df
    except Exception as e:
        print(f"Error loading data: {e}")
        return None

def create_latency_throughput_analysis(df):
    """Create comprehensive latency-throughput analysis"""
    
    # Create figure with subplots
    fig = plt.figure(figsize=(20, 16))
    
    # Define color schemes
    topo_colors = {'2x2_torus': '#E74C3C', '4x4_torus': '#3498DB', '8x8_torus': '#27AE60'}
    traffic_colors = plt.cm.Set3(np.linspace(0, 1, len(df['traffic_pattern'].unique())))
    
    # 1. Latency vs Injection Rate by Topology
    ax1 = plt.subplot(3, 3, 1)
    for topo in df['topology'].unique():
        topo_data = df[df['topology'] == topo]
        grouped = topo_data.groupby(['injection_rate', 'num_vcs'])['avg_latency'].mean().reset_index()
        
        for vc in sorted(df['num_vcs'].unique()):
            vc_data = grouped[grouped['num_vcs'] == vc]
            linestyle = '-' if vc == 1 else '--' if vc == 2 else ':'
            plt.plot(vc_data['injection_rate'], vc_data['avg_latency'], 
                    color=topo_colors[topo], linestyle=linestyle, 
                    marker='o', markersize=4, linewidth=2,
                    label=f'{topo} (VC={vc})')
    
    plt.xlabel('Injection Rate')
    plt.ylabel('Average Latency (cycles)')
    plt.title('Latency vs Injection Rate by Topology & VCs')
    plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left', fontsize=8)
    plt.grid(True, alpha=0.3)
    
    # 2. Throughput Saturation Analysis
    ax2 = plt.subplot(3, 3, 2)
    for topo in df['topology'].unique():
        topo_data = df[df['topology'] == topo]
        # Calculate saturation throughput (where latency starts increasing rapidly)
        grouped = topo_data.groupby('injection_rate')['throughput'].mean().reset_index()
        plt.plot(grouped['injection_rate'], grouped['throughput'], 
                color=topo_colors[topo], marker='s', markersize=6, linewidth=3,
                label=f'{topo}')
        
        # Add ideal throughput line
        plt.plot([0, 1], [0, 1], 'k--', alpha=0.5, linewidth=1)
    
    plt.xlabel('Injection Rate')
    plt.ylabel('Achieved Throughput')
    plt.title('Throughput Saturation by Topology')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # 3. Traffic Pattern Comparison Heatmap
    ax3 = plt.subplot(3, 3, 3)
    pivot_data = df.groupby(['traffic_pattern', 'topology'])['avg_latency'].mean().unstack()
    sns.heatmap(pivot_data, annot=True, fmt='.1f', cmap='YlOrRd', 
                cbar_kws={'label': 'Average Latency (cycles)'})
    plt.title('Latency Heatmap: Traffic vs Topology')
    plt.ylabel('Traffic Pattern')
    plt.xlabel('Topology')
    
    # 4. Virtual Channel Efficiency
    ax4 = plt.subplot(3, 3, 4)
    vc_analysis = df.groupby(['topology', 'num_vcs'])['avg_latency'].mean().unstack()
    vc_analysis.plot(kind='bar', ax=ax4, color=['#FF6B6B', '#4ECDC4', '#45B7D1'])
    plt.title('VC Impact on Average Latency')
    plt.ylabel('Average Latency (cycles)')
    plt.xlabel('Topology')
    plt.legend(title='Virtual Channels', bbox_to_anchor=(1.05, 1), loc='upper left')
    plt.xticks(rotation=45)
    
    # 5. Scalability Analysis
    ax5 = plt.subplot(3, 3, 5)
    scalability_data = df[df['injection_rate'] == 0.5]  # Fixed injection rate
    for pattern in ['uniform', 'transpose', 'bitcomp']:
        if pattern in df['traffic_pattern'].unique():
            pattern_data = scalability_data[scalability_data['traffic_pattern'] == pattern]
            pattern_grouped = pattern_data.groupby('nodes')['avg_latency'].mean()
            plt.plot(pattern_grouped.index, pattern_grouped.values, 
                    marker='o', linewidth=2, markersize=6, label=pattern)
    
    plt.xlabel('Number of Nodes')
    plt.ylabel('Average Latency (cycles)')
    plt.title('Scalability Analysis (Injection Rate = 0.5)')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # 6. Energy Efficiency (if available)
    ax6 = plt.subplot(3, 3, 6)
    if 'energy_per_packet' in df.columns and not df['energy_per_packet'].isna().all():
        energy_data = df.dropna(subset=['energy_per_packet'])
        if not energy_data.empty:
            sns.scatterplot(data=energy_data, x='throughput', y='energy_per_packet', 
                           hue='topology', style='traffic_pattern', s=60)
            plt.title('Energy vs Throughput Trade-off')
            plt.xlabel('Throughput')
            plt.ylabel('Energy per Packet')
    else:
        # Alternative: Hop count analysis
        hop_data = df.groupby(['topology', 'traffic_pattern'])['avg_hops'].mean().unstack()
        sns.heatmap(hop_data, annot=True, fmt='.2f', cmap='Blues')
        plt.title('Average Hop Count Analysis')
        plt.ylabel('Topology')
    
    # 7. Performance Distribution
    ax7 = plt.subplot(3, 3, 7)
    df_sample = df[df['injection_rate'].isin([0.3, 0.6, 0.9])]
    sns.violinplot(data=df_sample, x='injection_rate', y='avg_latency', hue='topology')
    plt.title('Latency Distribution by Load')
    plt.xlabel('Injection Rate')
    plt.ylabel('Average Latency (cycles)')
    
    # 8. Worst-Case Analysis
    ax8 = plt.subplot(3, 3, 8)
    worst_case = df.groupby(['topology', 'traffic_pattern'])['avg_latency'].max().unstack()
    worst_case.plot(kind='bar', ax=ax8, stacked=False, colormap='viridis')
    plt.title('Worst-Case Latency by Traffic Pattern')
    plt.ylabel('Maximum Latency (cycles)')
    plt.xlabel('Topology')
    plt.xticks(rotation=45)
    plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left', fontsize=8)
    
    # 9. Network Utilization Efficiency
    ax9 = plt.subplot(3, 3, 9)
    df['efficiency'] = df['throughput'] / df['injection_rate']
    efficiency_data = df.groupby(['topology', 'num_vcs'])['efficiency'].mean().unstack()
    efficiency_data.plot(kind='bar', ax=ax9, color=['#E74C3C', '#F39C12', '#9B59B6'])
    plt.title('Network Efficiency by VCs')
    plt.ylabel('Efficiency (Throughput/Injection Rate)')
    plt.xlabel('Topology')
    plt.axhline(y=1, color='k', linestyle='--', alpha=0.5, label='Ideal')
    plt.legend(title='Virtual Channels')
    plt.xticks(rotation=45)
    
    plt.tight_layout()
    return fig

def create_summary_report(df):
    """Generate a summary report of key findings"""
    
    print("\n" + "="*80)
    print("BOOKSIM2 NOC SIMULATION ANALYSIS REPORT")
    print("="*80)
    
    # Basic statistics
    print(f"\nDATASET OVERVIEW:")
    print(f"Total simulations: {len(df)}")
    print(f"Topologies tested: {', '.join(df['topology'].unique())}")
    print(f"Traffic patterns: {', '.join(df['traffic_pattern'].unique())}")
    print(f"Injection rates: {sorted(df['injection_rate'].unique())}")
    print(f"Virtual channels: {sorted(df['num_vcs'].unique())}")
    
    # Performance insights
    print(f"\nPERFORMANCE INSIGHTS:")
    
    # Best performing configurations
    best_latency = df.loc[df['avg_latency'].idxmin()]
    print(f"Lowest latency: {best_latency['avg_latency']:.2f} cycles")
    print(f"  Configuration: {best_latency['topology']}, {best_latency['traffic_pattern']}, rate={best_latency['injection_rate']}, VC={best_latency['num_vcs']}")
    
    best_throughput = df.loc[df['throughput'].idxmax()]
    print(f"Highest throughput: {best_throughput['throughput']:.3f}")
    print(f"  Configuration: {best_throughput['topology']}, {best_throughput['traffic_pattern']}, rate={best_throughput['injection_rate']}, VC={best_throughput['num_vcs']}")
    
    # Topology comparison
    print(f"\nTOPOLOGY COMPARISON (Average Latency):")
    topo_avg = df.groupby('topology')['avg_latency'].agg(['mean', 'std', 'min', 'max'])
    for topo, stats in topo_avg.iterrows():
        print(f"  {topo}: {stats['mean']:.2f} ± {stats['std']:.2f} cycles (range: {stats['min']:.2f}-{stats['max']:.2f})")
    
    # Traffic pattern analysis
    print(f"\nTRAFFIC PATTERN ANALYSIS:")
    traffic_avg = df.groupby('traffic_pattern')['avg_latency'].mean().sort_values()
    print("  Patterns ranked by average latency (best to worst):")
    for pattern, latency in traffic_avg.items():
        print(f"    {pattern}: {latency:.2f} cycles")
    
    # Virtual channel impact
    print(f"\nVIRTUAL CHANNEL IMPACT:")
    vc_impact = df.groupby('num_vcs')['avg_latency'].mean()
    for vc, latency in vc_impact.items():
        print(f"  {vc} VC(s): {latency:.2f} cycles average latency")
    
    # Saturation analysis
    print(f"\nSATURATION ANALYSIS:")
    high_load = df[df['injection_rate'] >= 0.8]
    if not high_load.empty:
        saturation_by_topo = high_load.groupby('topology')['avg_latency'].mean()
        print("  High-load performance (injection rate ≥ 0.8):")
        for topo, latency in saturation_by_topo.items():
            print(f"    {topo}: {latency:.2f} cycles")
    
    print("="*80 + "\n")

def main():
    """Main function to generate comprehensive analysis"""
    
    # Load data
    print("Loading simulation results...")
    df = load_and_clean_data('results/results.csv')
    
    if df is None or df.empty:
        print("Error: No valid data found in results.csv")
        return
    
    print(f"Loaded {len(df)} valid simulation results")
    
    # Generate visualizations
    print("Creating comprehensive visualization...")
    fig = create_latency_throughput_analysis(df)
    
    # Save the plot
    plt.savefig('plot.png', dpi=300, bbox_inches='tight', 
                facecolor='white', edgecolor='none')
    print("Visualization saved as 'plot.png'")
    
    # Generate summary report
    create_summary_report(df)
    
    # Show the plot
    plt.show()

if __name__ == "__main__":
    main()
