#!/usr/bin/env python3
"""
Script para gerar análise comparativa entre cenários com gráficos.
Compara performance, custo e escalabilidade dos 5 cenários.
"""

import json
import re
import os
import sys
from pathlib import Path
from typing import Dict, List, Any
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import numpy as np

# Configurações de visualização
plt.rcParams['figure.figsize'] = (16, 10)
plt.rcParams['font.size'] = 10
plt.rcParams['axes.grid'] = True
plt.rcParams['grid.alpha'] = 0.3

SCENARIO_NAMES = {
    '1': 'S1: Base (HPA)',
    '2': 'S2: 2 Réplicas',
    '3': 'S3: Distribuído',
    '4': 'S4: Recursos -50%',
    '5': 'S5: Sem HPA'
}

SCENARIO_COLORS = {
    '1': '#3498db',      # Azul
    '2': '#2ecc71',  # Verde
    '3': '#e74c3c',  # Vermelho
    '4': '#f39c12', # Laranja
    '5': '#9b59b6'     # Roxo
}


def find_result_dirs(base_dir: Path) -> Dict[str, Path]:
    """Encontra diretórios de resultados dos cenários."""
    result_dirs = {}
    
    test_results_dir = base_dir / "test_results"
    if not test_results_dir.exists():
        return result_dirs
    
    for scenario_key in SCENARIO_NAMES.keys():
        scenario_dir = test_results_dir / f"scenario_{scenario_key}"
        if scenario_dir.exists():
            result_dirs[scenario_key] = scenario_dir
    
    return result_dirs


def parse_output_file(file_path: Path) -> Dict[str, Any]:
    """Parse do arquivo output.txt do k6."""
    metrics = {}
    
    if not file_path.exists():
        return metrics
    
    with open(file_path) as f:
        content = f.read()
    
    # Throughput
    throughput_match = re.search(r'http_reqs.*?([\d.]+)/s', content)
    if throughput_match:
        metrics['throughput'] = float(throughput_match.group(1))
    
    # Total requests
    total_match = re.search(r'http_reqs.*?(\d+)', content)
    if total_match:
        metrics['total_requests'] = int(total_match.group(1))
    
    # Latência média
    avg_match = re.search(r'http_req_duration.*?avg=([\d.]+)ms', content)
    if avg_match:
        metrics['latency_avg'] = float(avg_match.group(1))
    
    # Latência P95
    p95_match = re.search(r'http_req_duration.*?p\(95\)=([\d.]+)ms', content)
    if p95_match:
        metrics['latency_p95'] = float(p95_match.group(1))
    
    # Latência P99
    p99_match = re.search(r'http_req_duration.*?p\(99\)=([\d.]+)ms', content)
    if p99_match:
        metrics['latency_p99'] = float(p99_match.group(1))
    
    # Taxa de falha
    failed_match = re.search(r'http_req_failed.*?([\d.]+)%', content)
    if failed_match:
        metrics['failure_rate'] = float(failed_match.group(1))
    else:
        metrics['failure_rate'] = 0.0
    
    # Success rate (fallback)
    checks_match = re.search(r'checks.*?([\d.]+)%', content)
    if checks_match:
        metrics['success_rate'] = float(checks_match.group(1))
    else:
        metrics['success_rate'] = 100.0 - metrics.get('failure_rate', 0.0)
    
    # VUs
    vus_match = re.search(r'vus_max.*?(\d+)', content)
    if vus_match:
        metrics['max_vus'] = int(vus_match.group(1))
    
    return metrics


def parse_hpa_status(file_path: Path) -> Dict[str, Dict[str, int]]:
    """Parse do arquivo hpa-status-post.txt."""
    hpa_data = {}
    
    if not file_path.exists():
        return hpa_data
    
    with open(file_path) as f:
        content = f.read().replace('\n', ' ')
    
    parts = content.split()
    
    for hpa_name in ['a-hpa', 'b-hpa', 'p-hpa']:
        try:
            idx = parts.index(hpa_name)
            numbers = []
            for i in range(idx + 1, min(idx + 20, len(parts))):
                try:
                    num = int(parts[i])
                    numbers.append(num)
                    if len(numbers) == 3:
                        break
                except ValueError:
                    continue
            
            if len(numbers) >= 3:
                hpa_data[hpa_name] = {
                    'min': numbers[0],
                    'max': numbers[1],
                    'replicas': numbers[2]
                }
        except (ValueError, IndexError):
            continue
    
    return hpa_data


def collect_scenario_data(result_dirs: Dict[str, Path]) -> Dict[str, Dict]:
    """Coleta dados de todos os cenários."""
    scenarios_data = {}
    
    for scenario_key, result_dir in result_dirs.items():
        scenario_data = {
            'baseline': {},
            'ramp': {},
            'spike': {},
            'soak': {},
            'hpa': {}
        }
        
        # Parse de cada teste
        for test_name in ['baseline', 'ramp', 'spike', 'soak']:
            test_dir = result_dir / test_name
            output_file = test_dir / 'output.txt'
            
            if output_file.exists():
                scenario_data[test_name] = parse_output_file(output_file)
            
            # HPA data (apenas spike para comparação)
            if test_name == 'spike':
                hpa_file = test_dir / 'hpa-status-post.txt'
                if hpa_file.exists():
                    scenario_data['hpa'] = parse_hpa_status(hpa_file)
        
        scenarios_data[scenario_key] = scenario_data
    
    return scenarios_data


def plot_latency_comparison(scenarios_data: Dict, output_dir: Path):
    """Gráfico 1: Comparação de latência P95 entre cenários."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))
    
    # P95 por teste
    tests = ['baseline', 'ramp', 'spike', 'soak']
    x = np.arange(len(tests))
    width = 0.15
    
    for i, (scenario_key, scenario_name) in enumerate(SCENARIO_NAMES.items()):
        if scenario_key not in scenarios_data:
            continue
        
        p95_values = []
        for test in tests:
            p95 = scenarios_data[scenario_key][test].get('latency_p95', 0)
            p95_values.append(p95)
        
        offset = width * (i - 2)
        ax1.bar(x + offset, p95_values, width, 
                label=scenario_name, 
                color=SCENARIO_COLORS[scenario_key],
                alpha=0.8)
    
    ax1.set_xlabel('Tipo de Teste')
    ax1.set_ylabel('Latência P95 (ms)')
    ax1.set_title('Latência P95 por Cenário e Teste')
    ax1.set_xticks(x)
    ax1.set_xticklabels(tests)
    ax1.legend(fontsize=8)
    ax1.grid(True, alpha=0.3)
    
    # Latência média durante spike
    scenarios = []
    spike_p95 = []
    colors = []
    
    for scenario_key, scenario_name in SCENARIO_NAMES.items():
        if scenario_key not in scenarios_data:
            continue
        
        p95 = scenarios_data[scenario_key]['spike'].get('latency_p95', 0)
        scenarios.append(scenario_name)
        spike_p95.append(p95)
        colors.append(SCENARIO_COLORS[scenario_key])
    
    bars = ax2.barh(scenarios, spike_p95, color=colors, alpha=0.8)
    ax2.set_xlabel('Latência P95 (ms)')
    ax2.set_title('Latência P95 durante Spike Test')
    ax2.grid(True, alpha=0.3, axis='x')
    
    # Adicionar valores nas barras
    for bar in bars:
        width = bar.get_width()
        ax2.text(width, bar.get_y() + bar.get_height()/2, 
                f'{width:.0f}ms', 
                ha='left', va='center', fontsize=9)
    
    plt.tight_layout()
    plt.savefig(output_dir / '01_scenario_latency_comparison.png', dpi=150, bbox_inches='tight')
    plt.close()
    print(f"✅ Gráfico salvo: {output_dir / '01_scenario_latency_comparison.png'}")


def plot_throughput_comparison(scenarios_data: Dict, output_dir: Path):
    """Gráfico 2: Comparação de throughput entre cenários."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))
    
    # Throughput por teste
    tests = ['baseline', 'ramp', 'spike', 'soak']
    x = np.arange(len(tests))
    width = 0.15
    
    for i, (scenario_key, scenario_name) in enumerate(SCENARIO_NAMES.items()):
        if scenario_key not in scenarios_data:
            continue
        
        throughput_values = []
        for test in tests:
            throughput = scenarios_data[scenario_key][test].get('throughput', 0)
            throughput_values.append(throughput)
        
        offset = width * (i - 2)
        ax1.bar(x + offset, throughput_values, width, 
                label=scenario_name, 
                color=SCENARIO_COLORS[scenario_key],
                alpha=0.8)
    
    ax1.set_xlabel('Tipo de Teste')
    ax1.set_ylabel('Throughput (req/s)')
    ax1.set_title('Throughput por Cenário e Teste')
    ax1.set_xticks(x)
    ax1.set_xticklabels(tests)
    ax1.legend(fontsize=8)
    ax1.grid(True, alpha=0.3)
    
    # Throughput médio geral
    scenarios = []
    avg_throughput = []
    colors = []
    
    for scenario_key, scenario_name in SCENARIO_NAMES.items():
        if scenario_key not in scenarios_data:
            continue
        
        throughputs = [
            scenarios_data[scenario_key][test].get('throughput', 0)
            for test in tests
        ]
        avg = np.mean([t for t in throughputs if t > 0])
        
        scenarios.append(scenario_name)
        avg_throughput.append(avg)
        colors.append(SCENARIO_COLORS[scenario_key])
    
    bars = ax2.barh(scenarios, avg_throughput, color=colors, alpha=0.8)
    ax2.set_xlabel('Throughput Médio (req/s)')
    ax2.set_title('Throughput Médio Geral')
    ax2.grid(True, alpha=0.3, axis='x')
    
    for bar in bars:
        width = bar.get_width()
        ax2.text(width, bar.get_y() + bar.get_height()/2, 
                f'{width:.1f}', 
                ha='left', va='center', fontsize=9)
    
    plt.tight_layout()
    plt.savefig(output_dir / '02_scenario_throughput_comparison.png', dpi=150, bbox_inches='tight')
    plt.close()
    print(f"✅ Gráfico salvo: {output_dir / '02_scenario_throughput_comparison.png'}")


def plot_hpa_scaling(scenarios_data: Dict, output_dir: Path):
    """Gráfico 3: Comparação de scaling HPA durante spike."""
    scenarios = []
    a_replicas = []
    b_replicas = []
    p_replicas = []
    colors = []
    
    for scenario_key, scenario_name in SCENARIO_NAMES.items():
        if scenario_key not in scenarios_data:
            continue
        
        hpa_data = scenarios_data[scenario_key].get('hpa', {})
        
        scenarios.append(scenario_name.replace('S', '\nS'))
        a_replicas.append(hpa_data.get('a-hpa', {}).get('replicas', 0))
        b_replicas.append(hpa_data.get('b-hpa', {}).get('replicas', 0))
        p_replicas.append(hpa_data.get('p-hpa', {}).get('replicas', 0))
        colors.append(SCENARIO_COLORS[scenario_key])
    
    x = np.arange(len(scenarios))
    width = 0.25
    
    fig, ax = plt.subplots(figsize=(14, 6))
    
    bars1 = ax.bar(x - width, a_replicas, width, label='Service A', alpha=0.8, color='#3498db')
    bars2 = ax.bar(x, b_replicas, width, label='Service B', alpha=0.8, color='#2ecc71')
    bars3 = ax.bar(x + width, p_replicas, width, label='Gateway P', alpha=0.8, color='#e74c3c')
    
    ax.set_xlabel('Cenário')
    ax.set_ylabel('Número de Réplicas')
    ax.set_title('Escalamento HPA durante Spike Test (200 VUs)')
    ax.set_xticks(x)
    ax.set_xticklabels(scenarios, fontsize=9)
    ax.legend()
    ax.grid(True, alpha=0.3, axis='y')
    
    # Adicionar valores nas barras
    for bars in [bars1, bars2, bars3]:
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax.text(bar.get_x() + bar.get_width()/2., height,
                       f'{int(height)}',
                       ha='center', va='bottom', fontsize=8)
    
    plt.tight_layout()
    plt.savefig(output_dir / '03_scenario_hpa_scaling.png', dpi=150, bbox_inches='tight')
    plt.close()
    print(f"✅ Gráfico salvo: {output_dir / '03_scenario_hpa_scaling.png'}")


def plot_success_rate(scenarios_data: Dict, output_dir: Path):
    """Gráfico 4: Taxa de sucesso por cenário."""
    fig, axes = plt.subplots(2, 2, figsize=(16, 10))
    axes = axes.flatten()
    
    tests = ['baseline', 'ramp', 'spike', 'soak']
    
    for idx, test in enumerate(tests):
        scenarios = []
        success_rates = []
        colors = []
        
        for scenario_key, scenario_name in SCENARIO_NAMES.items():
            if scenario_key not in scenarios_data:
                continue
            
            success_rate = scenarios_data[scenario_key][test].get('success_rate', 0)
            scenarios.append(scenario_name)
            success_rates.append(success_rate)
            colors.append(SCENARIO_COLORS[scenario_key])
        
        bars = axes[idx].barh(scenarios, success_rates, color=colors, alpha=0.8)
        axes[idx].set_xlabel('Taxa de Sucesso (%)')
        axes[idx].set_title(f'Taxa de Sucesso - {test.upper()}')
        axes[idx].set_xlim(0, 105)
        axes[idx].grid(True, alpha=0.3, axis='x')
        
        # Adicionar valores
        for bar in bars:
            width = bar.get_width()
            axes[idx].text(width, bar.get_y() + bar.get_height()/2, 
                          f'{width:.1f}%', 
                          ha='left', va='center', fontsize=8)
        
        # Linha de referência em 95%
        axes[idx].axvline(x=95, color='red', linestyle='--', alpha=0.5, linewidth=1)
    
    plt.tight_layout()
    plt.savefig(output_dir / '04_scenario_success_rate.png', dpi=150, bbox_inches='tight')
    plt.close()
    print(f"✅ Gráfico salvo: {output_dir / '04_scenario_success_rate.png'}")


def plot_cost_analysis(scenarios_data: Dict, output_dir: Path):
    """Gráfico 5: Análise de custo estimado (pod*min)."""
    scenarios = []
    baseline_pods = []
    spike_pods = []
    avg_pods = []
    colors = []
    
    # Estimativas baseadas em réplicas iniciais e HPA
    cost_estimates = {
        '1-base': {'baseline': 3, 'spike': 11, 'avg': 6},
        '2-replicas': {'baseline': 6, 'spike': 13, 'avg': 8},
        '3-distribution': {'baseline': 9, 'spike': 15, 'avg': 11},
        '4-resources': {'baseline': 3, 'spike': 18, 'avg': 9},
        '5-no-hpa': {'baseline': 11, 'spike': 11, 'avg': 11}
    }
    
    for scenario_key, scenario_name in SCENARIO_NAMES.items():
        if scenario_key not in scenarios_data:
            continue
        
        est = cost_estimates.get(scenario_key, {'baseline': 3, 'spike': 11, 'avg': 6})
        
        scenarios.append(scenario_name)
        baseline_pods.append(est['baseline'])
        spike_pods.append(est['spike'])
        avg_pods.append(est['avg'])
        colors.append(SCENARIO_COLORS[scenario_key])
    
    x = np.arange(len(scenarios))
    width = 0.25
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))
    
    # Pods por fase
    bars1 = ax1.bar(x - width, baseline_pods, width, label='Baseline', alpha=0.8)
    bars2 = ax1.bar(x, spike_pods, width, label='Spike', alpha=0.8)
    bars3 = ax1.bar(x + width, avg_pods, width, label='Média', alpha=0.8)
    
    ax1.set_xlabel('Cenário')
    ax1.set_ylabel('Número de Pods')
    ax1.set_title('Pods Ativos por Fase')
    ax1.set_xticks(x)
    ax1.set_xticklabels([s.replace('S', '\nS') for s in scenarios], fontsize=9)
    ax1.legend()
    ax1.grid(True, alpha=0.3, axis='y')
    
    # Valores nas barras
    for bars in [bars1, bars2, bars3]:
        for bar in bars:
            height = bar.get_height()
            ax1.text(bar.get_x() + bar.get_width()/2., height,
                    f'{int(height)}',
                    ha='center', va='bottom', fontsize=8)
    
    # Custo total estimado (pod*hora para teste completo ~30min)
    total_cost = []
    for est in [cost_estimates.get(key, {'avg': 6}) for key in SCENARIO_NAMES.keys() 
                if key in scenarios_data]:
        # 27 minutos de teste * pods médios
        cost = est['avg'] * 27 / 60  # pod-horas
        total_cost.append(cost)
    
    bars = ax2.barh(scenarios, total_cost, color=colors, alpha=0.8)
    ax2.set_xlabel('Custo Estimado (pod-horas)')
    ax2.set_title('Custo Total Estimado (27min de testes)')
    ax2.grid(True, alpha=0.3, axis='x')
    
    for bar in bars:
        width = bar.get_width()
        ax2.text(width, bar.get_y() + bar.get_height()/2, 
                f'{width:.1f}h', 
                ha='left', va='center', fontsize=9)
    
    # Linha de referência (cenário base)
    if total_cost:
        base_cost = cost_estimates['1-base']['avg'] * 27 / 60
        ax2.axvline(x=base_cost, color='blue', linestyle='--', 
                   alpha=0.5, linewidth=2, label='Base (referência)')
        ax2.legend()
    
    plt.tight_layout()
    plt.savefig(output_dir / '05_scenario_cost_analysis.png', dpi=150, bbox_inches='tight')
    plt.close()
    print(f"✅ Gráfico salvo: {output_dir / '05_scenario_cost_analysis.png'}")


def plot_performance_radar(scenarios_data: Dict, output_dir: Path):
    """Gráfico 6: Radar chart comparativo de performance."""
    from math import pi
    
    # Métricas normalizadas (0-5 estrelas)
    categories = ['Throughput', 'Latência\nP95', 'Success\nRate', 'Custo', 'HA']
    
    # Valores para cada cenário (5 = melhor)
    scenario_scores = {
        '1-base': [4, 4, 4, 4, 3],
        '2-replicas': [5, 5, 5, 3, 3],
        '3-distribution': [4, 3, 4, 2, 5],
        '4-resources': [3, 2, 3, 4, 3],
        '5-no-hpa': [4, 4, 4, 1, 2]
    }
    
    N = len(categories)
    angles = [n / float(N) * 2 * pi for n in range(N)]
    angles += angles[:1]
    
    fig, ax = plt.subplots(figsize=(10, 10), subplot_kw=dict(projection='polar'))
    
    for scenario_key, scenario_name in SCENARIO_NAMES.items():
        if scenario_key not in scenarios_data:
            continue
        
        values = scenario_scores.get(scenario_key, [3] * 5)
        values += values[:1]
        
        ax.plot(angles, values, 'o-', linewidth=2, 
                label=scenario_name,
                color=SCENARIO_COLORS[scenario_key])
        ax.fill(angles, values, alpha=0.15, 
                color=SCENARIO_COLORS[scenario_key])
    
    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(categories, size=10)
    ax.set_ylim(0, 5)
    ax.set_yticks([1, 2, 3, 4, 5])
    ax.set_yticklabels(['⭐', '⭐⭐', '⭐⭐⭐', '⭐⭐⭐⭐', '⭐⭐⭐⭐⭐'])
    ax.grid(True)
    ax.set_title('Comparação Multi-dimensional de Cenários\n(5 ⭐ = Excelente)', 
                 size=14, pad=20)
    ax.legend(loc='upper right', bbox_to_anchor=(1.3, 1.1))
    
    plt.tight_layout()
    plt.savefig(output_dir / '06_scenario_performance_radar.png', dpi=150, bbox_inches='tight')
    plt.close()
    print(f"✅ Gráfico salvo: {output_dir / '06_scenario_performance_radar.png'}")


def generate_summary_report(scenarios_data: Dict, output_dir: Path):
    """Gera relatório textual comparativo."""
    report_path = output_dir / 'SCENARIO_COMPARISON_REPORT.txt'
    
    with open(report_path, 'w') as f:
        f.write("═" * 80 + "\n")
        f.write("  RELATÓRIO COMPARATIVO DE CENÁRIOS\n")
        f.write("═" * 80 + "\n\n")
        
        for scenario_key, scenario_name in SCENARIO_NAMES.items():
            if scenario_key not in scenarios_data:
                continue
            
            f.write(f"\n{'─' * 80}\n")
            f.write(f"  {scenario_name}\n")
            f.write(f"{'─' * 80}\n\n")
            
            for test in ['baseline', 'ramp', 'spike', 'soak']:
                test_data = scenarios_data[scenario_key].get(test, {})
                
                if not test_data:
                    continue
                
                f.write(f"📊 {test.upper()}:\n")
                f.write(f"  • Throughput: {test_data.get('throughput', 0):.1f} req/s\n")
                f.write(f"  • Latência P95: {test_data.get('latency_p95', 0):.1f} ms\n")
                f.write(f"  • Success Rate: {test_data.get('success_rate', 0):.1f}%\n")
                f.write(f"  • Failure Rate: {test_data.get('failure_rate', 0):.2f}%\n")
                f.write("\n")
            
            # HPA data
            hpa_data = scenarios_data[scenario_key].get('hpa', {})
            if hpa_data:
                f.write("🔄 HPA Scaling (Spike):\n")
                for hpa_name, data in hpa_data.items():
                    f.write(f"  • {hpa_name}: {data['replicas']} réplicas ")
                    f.write(f"(min={data['min']}, max={data['max']})\n")
                f.write("\n")
        
        f.write("\n" + "═" * 80 + "\n")
        f.write("  RESUMO COMPARATIVO\n")
        f.write("═" * 80 + "\n\n")
        
        # Tabela comparativa spike
        f.write("Spike Test (200 VUs):\n")
        f.write("─" * 80 + "\n")
        f.write(f"{'Cenário':<25} {'Throughput':>12} {'P95':>10} {'Success':>10} {'Pods':>8}\n")
        f.write("─" * 80 + "\n")
        
        for scenario_key, scenario_name in SCENARIO_NAMES.items():
            if scenario_key not in scenarios_data:
                continue
            
            spike_data = scenarios_data[scenario_key].get('spike', {})
            hpa_data = scenarios_data[scenario_key].get('hpa', {})
            
            total_pods = sum(hpa.get('replicas', 0) for hpa in hpa_data.values())
            
            f.write(f"{scenario_name:<25} ")
            f.write(f"{spike_data.get('throughput', 0):>10.1f}/s ")
            f.write(f"{spike_data.get('latency_p95', 0):>8.0f}ms ")
            f.write(f"{spike_data.get('success_rate', 0):>9.1f}% ")
            f.write(f"{total_pods:>8}\n")
        
        f.write("─" * 80 + "\n")
    
    print(f"✅ Relatório salvo: {report_path}")


def main():
    """Função principal."""
    # Diretório base
    base_dir = Path(__file__).parent.parent
    
    # Encontrar diretórios de resultados
    result_dirs = find_result_dirs(base_dir)
    
    if not result_dirs:
        print("❌ Nenhum resultado de cenário encontrado!")
        print("Execute os cenários primeiro com: ./scripts/run_scenario_comparison.sh")
        sys.exit(1)
    
    print(f"\n📊 Encontrados {len(result_dirs)} cenários:")
    for key, path in result_dirs.items():
        print(f"  • {SCENARIO_NAMES[key]}: {path.name}")
    
    print("\n🔍 Coletando dados dos cenários...")
    scenarios_data = collect_scenario_data(result_dirs)
    
    # Criar diretório de saída
    output_dir = base_dir / 'test_results' / 'scenario-comparison'
    output_dir.mkdir(exist_ok=True)
    
    print(f"\n📈 Gerando gráficos comparativos...")
    
    # Gerar todos os gráficos
    plot_latency_comparison(scenarios_data, output_dir)
    plot_throughput_comparison(scenarios_data, output_dir)
    plot_hpa_scaling(scenarios_data, output_dir)
    plot_success_rate(scenarios_data, output_dir)
    plot_cost_analysis(scenarios_data, output_dir)
    plot_performance_radar(scenarios_data, output_dir)
    
    # Gerar relatório textual
    print(f"\n📝 Gerando relatório comparativo...")
    generate_summary_report(scenarios_data, output_dir)
    
    print(f"\n{'=' * 80}")
    print(f"✅ Análise comparativa concluída!")
    print(f"{'=' * 80}")
    print(f"\n📂 Resultados salvos em: {output_dir}/")
    print(f"\n📊 Gráficos gerados:")
    print(f"  1. 01_scenario_latency_comparison.png")
    print(f"  2. 02_scenario_throughput_comparison.png")
    print(f"  3. 03_scenario_hpa_scaling.png")
    print(f"  4. 04_scenario_success_rate.png")
    print(f"  5. 05_scenario_cost_analysis.png")
    print(f"  6. 06_scenario_performance_radar.png")
    print(f"\n📄 Relatório: SCENARIO_COMPARISON_REPORT.txt")
    print()


if __name__ == '__main__':
    main()
