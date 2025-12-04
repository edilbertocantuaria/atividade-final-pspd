#!/usr/bin/env python3
"""
Script para análise e geração de gráficos dos testes de observabilidade K8s
Baseado nos resultados do k6 e métricas do Kubernetes
"""

import os
import re
import json
import sys
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from pathlib import Path

# Diretórios - suporta tanto results/ (antigo) quanto test_results/ (novo)
if len(sys.argv) > 1:
    # Modo: python analyze_results.py test_results/scenario_1
    RESULTS_DIR = Path(sys.argv[1])
    PLOTS_DIR = RESULTS_DIR / "plots"
else:
    # Modo legado: python analyze_results.py (usa results/)
    RESULTS_DIR = Path("results")
    PLOTS_DIR = RESULTS_DIR / "plots"

PLOTS_DIR.mkdir(exist_ok=True, parents=True)

# Configuração de estilo
plt.style.use('seaborn-v0_8-darkgrid')
COLORS = {
    'baseline': '#2ecc71',
    'ramp': '#3498db',
    'spike': '#e74c3c',
    'soak': '#f39c12'
}

def parse_k6_output(file_path):
    """Extrai métricas do output do k6"""
    if not file_path.exists():
        return None
    
    # Ler apenas as últimas 100 linhas (onde ficam as estatísticas)
    with open(file_path) as f:
        lines = f.readlines()
        # Pegar últimas 100 linhas ou todas se houver menos
        content = ''.join(lines[-100:])
    
    # Remover quebras de linha no meio das linhas de métricas para facilitar parsing
    # Substitui quebras de linha seguidas de espaços por um único espaço
    content = re.sub(r'\n\s+', ' ', content)
    
    metrics = {}
    
    # Extrair http_req_duration (formato: min=X avg=Y med=Z max=W p(90)=T p(95)=V p(99)=U)
    duration_match = re.search(r'http_req_duration.*?min=([\d.\-]+)(\w+)\s+avg=([\d.\-]+)(\w+)\s+med=([\d.\-]+)(\w+)\s+max=([\d.\-]+)(\w+)\s+p\(90\)=([\d.\-]+)(\w+)\s+p\(95\)=([\d.\-]+)(\w+)', content)
    if duration_match:
        metrics['min_duration'] = float(duration_match.group(1))
        metrics['avg_duration'] = float(duration_match.group(3))
        metrics['med_duration'] = float(duration_match.group(5))
        metrics['max_duration'] = float(duration_match.group(7))
        metrics['p90_duration'] = float(duration_match.group(9))
        metrics['p95_duration'] = float(duration_match.group(11))
        # Tentar pegar p99 também
        p99_match = re.search(r'p\(99\)=([\d.\-]+)(\w+)', content)
        if p99_match:
            metrics['p99_duration'] = float(p99_match.group(1))
    
    # Extrair http_reqs
    reqs_match = re.search(r'http_reqs.*?(\d+)\s+([\d.]+)/s', content)
    if reqs_match:
        metrics['total_requests'] = int(reqs_match.group(1))
        metrics['requests_per_sec'] = float(reqs_match.group(2))
    
    # Extrair checks
    checks_match = re.search(r'checks.*?([\d.]+)%', content)
    if checks_match:
        metrics['success_rate'] = float(checks_match.group(1))
    else:
        # Se não há checks, calcular taxa de sucesso a partir de http_req_failed
        metrics['success_rate'] = 100.0 - metrics.get('failure_rate', 0.0)
    
    # Extrair http_req_failed
    failed_match = re.search(r'http_req_failed.*?([\d.]+)%', content)
    if failed_match:
        metrics['failure_rate'] = float(failed_match.group(1))
    else:
        metrics['failure_rate'] = 0.0
    
    # Extrair VUs
    vus_match = re.search(r'vus.*?max=(\d+)', content)
    if vus_match:
        metrics['max_vus'] = int(vus_match.group(1))
    
    # Extrair iterations
    iter_match = re.search(r'iterations.*?(\d+)', content)
    if iter_match:
        metrics['iterations'] = int(iter_match.group(1))
    
    return metrics

def parse_hpa_status(file_path):
    """Extrai informações do HPA"""
    if not file_path.exists():
        return {}
    
    with open(file_path) as f:
        content = f.read()
    
    # Verificar se há erro de conexão
    if 'connection' in content.lower() and 'refused' in content.lower():
        return {}
    
    # Verificar se está vazio
    if not content.strip():
        return {}
    
    # Join all lines to handle wrapped text
    content = content.replace('\n', ' ')
    
    # Split by spaces
    parts = content.split()
    
    hpa_data = {}
    
    # Find each HPA entry
    for hpa_name in ['a-hpa', 'b-hpa', 'p-hpa']:
        try:
            idx = parts.index(hpa_name)
            # After name: REFERENCE TARGETS... then 3 numbers: MINPODS MAXPODS REPLICAS
            # Find next 3 consecutive numbers after the name
            numbers = []
            for i in range(idx + 1, min(idx + 20, len(parts))):  # Look ahead max 20 positions
                try:
                    num = int(parts[i])
                    numbers.append(num)
                    if len(numbers) == 3:
                        break
                except ValueError:
                    continue
            
            if len(numbers) == 3:
                hpa_data[hpa_name] = {
                    'min': numbers[0],
                    'max': numbers[1],
                    'replicas': numbers[2]
                }
        except (ValueError, IndexError):
            pass
    
    return hpa_data

def parse_pod_metrics(file_path):
    """Extrai métricas de CPU/Memory dos pods"""
    if not file_path.exists():
        return {}
    
    with open(file_path) as f:
        content = f.read()
    
    # Verificar se há erro de conexão
    if 'connection' in content.lower() and 'refused' in content.lower():
        return {}
    
    # Verificar se está vazio
    if not content.strip():
        return {}
    
    lines = content.split('\n')
    
    metrics = {}
    for line in lines[1:]:  # Skip header
        parts = line.split()
        if len(parts) >= 3:
            pod_name = parts[0]
            cpu = parts[1]
            memory = parts[2]
            
            # Converter CPU (ex: 50m -> 50, 1 -> 1000)
            cpu_value = int(cpu.replace('m', '')) if 'm' in cpu else int(cpu) * 1000
            
            # Converter Memory (ex: 100Mi -> 100)
            memory_value = int(memory.replace('Mi', ''))
            
            # Identificar tipo de pod
            if 'p-deploy' in pod_name:
                service = 'gateway-p'
            elif 'a-deploy' in pod_name:
                service = 'service-a'
            elif 'b-deploy' in pod_name:
                service = 'service-b'
            else:
                continue
            
            if service not in metrics:
                metrics[service] = {'cpu': [], 'memory': []}
            
            metrics[service]['cpu'].append(cpu_value)
            metrics[service]['memory'].append(memory_value)
    
    # Calcular médias
    for service in metrics:
        if metrics[service]['cpu']:
            metrics[service]['avg_cpu'] = sum(metrics[service]['cpu']) / len(metrics[service]['cpu'])
            metrics[service]['avg_memory'] = sum(metrics[service]['memory']) / len(metrics[service]['memory'])
    
    return metrics

def collect_all_metrics():
    """Coleta métricas de todos os testes"""
    scenarios = ['baseline', 'ramp', 'spike', 'soak']
    all_metrics = {}
    
    for scenario in scenarios:
        # Suporta tanto results/baseline/ quanto test_results/scenario_X/baseline/
        scenario_dir = RESULTS_DIR / scenario
        if not scenario_dir.exists():
            continue
        
        data = {}
        
        # Parse k6 output
        output_file = scenario_dir / "output.txt"
        k6_metrics = parse_k6_output(output_file)
        if k6_metrics:
            data['k6'] = k6_metrics
        
        # Parse HPA (pre e post)
        hpa_pre = parse_hpa_status(scenario_dir / "hpa-status-pre.txt")
        hpa_post = parse_hpa_status(scenario_dir / "hpa-status-post.txt")
        if hpa_pre or hpa_post:
            data['hpa'] = {'pre': hpa_pre, 'post': hpa_post}
        
        # Parse pod metrics (pre e post)
        pod_pre = parse_pod_metrics(scenario_dir / "pod-metrics-pre.txt")
        pod_post = parse_pod_metrics(scenario_dir / "pod-metrics-post.txt")
        if pod_pre or pod_post:
            data['pods'] = {'pre': pod_pre, 'post': pod_post}
        
        all_metrics[scenario] = data
    
    return all_metrics

def plot_latency_comparison(metrics):
    """Gráfico 1: Comparação de latências entre cenários"""
    fig, ax = plt.subplots(figsize=(12, 6))
    
    scenarios = []
    avg_latencies = []
    p95_latencies = []
    p90_latencies = []
    
    for scenario, data in sorted(metrics.items()):
        if 'k6' in data and 'avg_duration' in data['k6']:
            scenarios.append(scenario.upper())
            avg_latencies.append(data['k6']['avg_duration'])
            p95_latencies.append(data['k6'].get('p95_duration', 0))
            p90_latencies.append(data['k6'].get('p90_duration', 0))
    
    x = range(len(scenarios))
    width = 0.25
    
    ax.bar([i - width for i in x], avg_latencies, width, label='Média', color='#3498db')
    ax.bar(x, p90_latencies, width, label='p90', color='#f39c12')
    ax.bar([i + width for i in x], p95_latencies, width, label='p95', color='#e74c3c')
    
    ax.set_xlabel('Cenário de Teste', fontsize=12, fontweight='bold')
    ax.set_ylabel('Latência (ms)', fontsize=12, fontweight='bold')
    ax.set_title('Comparação de Latências entre Cenários', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(scenarios)
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(PLOTS_DIR / "01_latency_comparison.png", dpi=300, bbox_inches='tight')
    print(f"✅ Gráfico salvo: {PLOTS_DIR / '01_latency_comparison.png'}")
    plt.close()

def plot_throughput_comparison(metrics):
    """Gráfico 2: Comparação de throughput"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
    
    scenarios = []
    req_per_sec = []
    total_reqs = []
    
    for scenario, data in sorted(metrics.items()):
        if 'k6' in data:
            scenarios.append(scenario.upper())
            req_per_sec.append(data['k6'].get('requests_per_sec', 0))
            total_reqs.append(data['k6'].get('total_requests', 0))
    
    # Requisições por segundo
    colors = [COLORS.get(s.lower(), '#95a5a6') for s in scenarios]
    ax1.bar(scenarios, req_per_sec, color=colors)
    ax1.set_ylabel('Requisições/segundo', fontsize=11, fontweight='bold')
    ax1.set_title('Throughput (req/s)', fontsize=12, fontweight='bold')
    ax1.grid(True, alpha=0.3, axis='y')
    
    # Total de requisições
    ax2.bar(scenarios, total_reqs, color=colors)
    ax2.set_ylabel('Total de Requisições', fontsize=11, fontweight='bold')
    ax2.set_title('Volume Total Processado', fontsize=12, fontweight='bold')
    ax2.grid(True, alpha=0.3, axis='y')
    
    plt.suptitle('Análise de Throughput', fontsize=14, fontweight='bold')
    plt.tight_layout()
    plt.savefig(PLOTS_DIR / "02_throughput_comparison.png", dpi=300, bbox_inches='tight')
    print(f"✅ Gráfico salvo: {PLOTS_DIR / '02_throughput_comparison.png'}")
    plt.close()

def plot_success_rate(metrics):
    """Gráfico 3: Taxa de sucesso e falhas"""
    fig, ax = plt.subplots(figsize=(10, 6))
    
    scenarios = []
    success_rates = []
    failure_rates = []
    
    for scenario, data in sorted(metrics.items()):
        if 'k6' in data:
            scenarios.append(scenario.upper())
            # Usar apenas http_req_failed para calcular sucesso/falha
            failure_rate = data['k6'].get('failure_rate', 0)
            success_rate = 100.0 - failure_rate
            success_rates.append(success_rate)
            failure_rates.append(failure_rate)
    
    x = range(len(scenarios))
    width = 0.35
    
    # Criar barras empilhadas para mostrar sucesso + falha = 100%
    ax.bar(x, success_rates, width, label='Sucesso (%)', color='#2ecc71')
    ax.bar(x, failure_rates, width, bottom=success_rates, label='Falha (%)', color='#e74c3c')
    
    # Adicionar valores nas barras
    for i in x:
        # Valor de sucesso
        if success_rates[i] > 5:  # Só mostrar se tiver espaço
            ax.text(i, success_rates[i]/2, f'{success_rates[i]:.1f}%', ha='center', va='center', 
                   fontsize=10, fontweight='bold', color='white')
        # Valor de falha
        if failure_rates[i] > 5:  # Só mostrar se tiver espaço
            ax.text(i, success_rates[i] + failure_rates[i]/2, f'{failure_rates[i]:.1f}%', 
                   ha='center', va='center', fontsize=10, fontweight='bold', color='white')
    
    ax.set_xlabel('Cenário', fontsize=12, fontweight='bold')
    ax.set_ylabel('Percentual (%)', fontsize=12, fontweight='bold')
    ax.set_title('Taxa de Sucesso vs Falha por Cenário', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(scenarios)
    ax.legend()
    ax.set_ylim(0, 105)
    ax.grid(True, alpha=0.3, axis='y')
    
    # Adicionar linha de referência em 100%
    ax.axhline(y=100, color='gray', linestyle='--', alpha=0.5, linewidth=1)
    
    plt.tight_layout()
    plt.savefig(PLOTS_DIR / "03_success_rate.png", dpi=300, bbox_inches='tight')
    print(f"✅ Gráfico salvo: {PLOTS_DIR / '03_success_rate.png'}")
    plt.close()

def plot_hpa_scaling(metrics):
    """Gráfico 4: Comportamento do HPA (autoscaling)"""
    fig, axes = plt.subplots(3, 1, figsize=(12, 10))
    
    services = ['p-hpa', 'a-hpa', 'b-hpa']
    service_names = ['Gateway P', 'Service A', 'Service B']
    
    has_any_data = False
    
    for idx, (service, name) in enumerate(zip(services, service_names)):
        ax = axes[idx]
        scenarios = []
        replicas_pre = []
        replicas_post = []
        
        for scenario, data in sorted(metrics.items()):
            if 'hpa' in data and (data['hpa']['pre'] or data['hpa']['post']):
                scenarios.append(scenario.upper())
                pre_val = data['hpa']['pre'].get(service, {}).get('replicas', 0)
                post_val = data['hpa']['post'].get(service, {}).get('replicas', 0)
                replicas_pre.append(pre_val)
                replicas_post.append(post_val)
                has_any_data = True
        
        if scenarios:
            x = range(len(scenarios))
            width = 0.35
            
            ax.bar([i - width/2 for i in x], replicas_pre, width, label='Pré-teste', color='#3498db', alpha=0.7, edgecolor='black', linewidth=1)
            ax.bar([i + width/2 for i in x], replicas_post, width, label='Pós-teste', color='#e74c3c', alpha=0.7, edgecolor='black', linewidth=1)
            
            # Adicionar valores nas barras
            for i in x:
                if replicas_pre[i] > 0:
                    ax.text(i - width/2, replicas_pre[i] + 0.1, str(int(replicas_pre[i])), ha='center', va='bottom', fontsize=9, fontweight='bold')
                if replicas_post[i] > 0:
                    ax.text(i + width/2, replicas_post[i] + 0.1, str(int(replicas_post[i])), ha='center', va='bottom', fontsize=9, fontweight='bold')
            
            ax.set_ylabel('Réplicas', fontsize=11, fontweight='bold')
            ax.set_title(f'{name} - Scaling Behavior', fontsize=12, fontweight='bold')
            ax.set_xticks(x)
            ax.set_xticklabels(scenarios)
            ax.legend()
            ax.grid(True, alpha=0.3, axis='y')
            ax.set_ylim(0, max(max(replicas_pre + replicas_post, default=1) * 1.2, 1))
            ax.set_ylim(0, max(replicas_post + [1]) + 1)
        else:
            # Mostrar mensagem informativa
            ax.text(0.5, 0.5, f'{name}\n\n⚠️ Dados de HPA não disponíveis\n\nVerifique se o cluster Kubernetes\nestá em execução durante os testes',
                   ha='center', va='center', fontsize=11, transform=ax.transAxes,
                   bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.3))
            ax.set_xlim(0, 1)
            ax.set_ylim(0, 1)
            ax.axis('off')
    
    if not has_any_data:
        plt.suptitle('Horizontal Pod Autoscaler - Dados Não Disponíveis', fontsize=14, fontweight='bold', color='#e74c3c')
    else:
        plt.suptitle('Horizontal Pod Autoscaler - Evolução de Réplicas', fontsize=14, fontweight='bold')
    
    plt.tight_layout()
    plt.savefig(PLOTS_DIR / "04_hpa_scaling.png", dpi=300, bbox_inches='tight')
    print(f"✅ Gráfico salvo: {PLOTS_DIR / '04_hpa_scaling.png'}")
    plt.close()

def plot_resource_usage(metrics):
    """Gráfico 5: Uso de CPU e Memória"""
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10))
    
    services_map = {'gateway-p': 'Gateway P', 'service-a': 'Service A', 'service-b': 'Service B'}
    
    has_cpu_data = False
    has_mem_data = False
    
    # CPU Usage
    for scenario, data in sorted(metrics.items()):
        if 'pods' in data and 'post' in data['pods'] and data['pods']['post']:
            x_pos = []
            cpu_values = []
            labels = []
            
            for service, pod_data in data['pods']['post'].items():
                if 'avg_cpu' in pod_data:
                    labels.append(services_map.get(service, service))
                    cpu_values.append(pod_data['avg_cpu'])
            
            if cpu_values:
                x = range(len(labels))
                ax1.plot(x, cpu_values, marker='o', label=scenario.upper(), linewidth=2)
                has_cpu_data = True
    
    if has_cpu_data and ax1.get_lines():
        ax1.set_xticks(range(len(labels)))
        ax1.set_xticklabels(labels)
        ax1.set_ylabel('CPU (millicores)', fontsize=11, fontweight='bold')
        ax1.set_title('Uso de CPU por Serviço', fontsize=12, fontweight='bold')
        ax1.legend()
        ax1.grid(True, alpha=0.3)
    else:
        ax1.text(0.5, 0.5, '⚠️ Dados de CPU não disponíveis\n\nVerifique se o metrics-server está instalado:\nkubectl top pods -n pspd',
                ha='center', va='center', fontsize=11, transform=ax1.transAxes,
                bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.3))
        ax1.set_xlim(0, 1)
        ax1.set_ylim(0, 1)
        ax1.set_title('Uso de CPU por Serviço - Dados Não Disponíveis', fontsize=12, fontweight='bold')
        ax1.axis('off')
    
    # Memory Usage
    for scenario, data in sorted(metrics.items()):
        if 'pods' in data and 'post' in data['pods'] and data['pods']['post']:
            mem_values = []
            labels = []
            
            for service, pod_data in data['pods']['post'].items():
                if 'avg_memory' in pod_data:
                    labels.append(services_map.get(service, service))
                    mem_values.append(pod_data['avg_memory'])
            
            if mem_values:
                x = range(len(labels))
                ax2.plot(x, mem_values, marker='s', label=scenario.upper(), linewidth=2)
                has_mem_data = True
    
    if has_mem_data and ax2.get_lines():
        ax2.set_xticks(range(len(labels)))
        ax2.set_xticklabels(labels)
        ax2.set_ylabel('Memory (Mi)', fontsize=11, fontweight='bold')
        ax2.set_title('Uso de Memória por Serviço', fontsize=12, fontweight='bold')
        ax2.legend()
        ax2.grid(True, alpha=0.3)
    else:
        ax2.text(0.5, 0.5, '⚠️ Dados de Memória não disponíveis\n\nVerifique se o metrics-server está instalado:\nkubectl top pods -n pspd',
                ha='center', va='center', fontsize=11, transform=ax2.transAxes,
                bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.3))
        ax2.set_xlim(0, 1)
        ax2.set_ylim(0, 1)
        ax2.set_title('Uso de Memória por Serviço - Dados Não Disponíveis', fontsize=12, fontweight='bold')
        ax2.axis('off')
    
    if not has_cpu_data and not has_mem_data:
        plt.suptitle('Análise de Recursos (CPU e Memória) - Dados Não Disponíveis', fontsize=14, fontweight='bold', color='#e74c3c')
    else:
        plt.suptitle('Análise de Recursos (CPU e Memória)', fontsize=14, fontweight='bold')
    
    plt.tight_layout()
    plt.savefig(PLOTS_DIR / "05_resource_usage.png", dpi=300, bbox_inches='tight')
    print(f"✅ Gráfico salvo: {PLOTS_DIR / '05_resource_usage.png'}")
    plt.close()

def plot_latency_percentiles(metrics):
    """Gráfico 6: Distribuição de percentis de latência"""
    fig, ax = plt.subplots(figsize=(12, 7))
    
    # Inicializar labels fora do loop
    percentiles = ['min_duration', 'avg_duration', 'med_duration', 'p90_duration', 'p95_duration', 'max_duration']
    labels = ['Min', 'Avg', 'Median', 'p90', 'p95', 'Max']
    
    has_data = False
    for scenario, data in sorted(metrics.items()):
        if 'k6' in data and 'avg_duration' in data['k6']:
            # Substituir valores 0 por 0.01 para evitar problemas com escala log
            values = [max(data['k6'].get(p, 0), 0.01) for p in percentiles]
            
            x = range(len(labels))
            ax.plot(x, values, marker='o', label=scenario.upper(), linewidth=2.5, markersize=8)
            has_data = True
    
    if has_data:
        ax.set_xticks(range(len(labels)))
        ax.set_xticklabels(labels)
        ax.set_xlabel('Percentil', fontsize=12, fontweight='bold')
        ax.set_ylabel('Latência (ms)', fontsize=12, fontweight='bold')
        ax.set_title('Distribuição de Latência por Percentil', fontsize=14, fontweight='bold')
        ax.legend(fontsize=10)
        ax.grid(True, alpha=0.3)
        ax.set_yscale('log')  # Escala logarítmica para melhor visualização
    
    plt.tight_layout()
    plt.savefig(PLOTS_DIR / "06_latency_percentiles.png", dpi=300, bbox_inches='tight')
    print(f"✅ Gráfico salvo: {PLOTS_DIR / '06_latency_percentiles.png'}")
    plt.close()

def generate_summary_report(metrics):
    """Gera relatório textual resumido"""
    report_path = PLOTS_DIR / "SUMMARY_REPORT.txt"
    
    with open(report_path, 'w') as f:
        f.write("═" * 70 + "\n")
        f.write("  RELATÓRIO DE ANÁLISE - TESTES DE OBSERVABILIDADE K8S\n")
        f.write("═" * 70 + "\n\n")
        
        for scenario, data in sorted(metrics.items()):
            f.write(f"\n{'─' * 70}\n")
            f.write(f"  {scenario.upper()}\n")
            f.write(f"{'─' * 70}\n\n")
            
            if 'k6' in data:
                k6 = data['k6']
                f.write("📊 Métricas de Performance (k6):\n")
                f.write(f"  • Throughput: {k6.get('requests_per_sec', 0):.2f} req/s\n")
                f.write(f"  • Total de requisições: {k6.get('total_requests', 0):,}\n")
                f.write(f"  • Latência média: {k6.get('avg_duration', 0):.2f} ms\n")
                f.write(f"  • Latência p95: {k6.get('p95_duration', 0):.2f} ms\n")
                # Calcular success_rate baseado em failure_rate
                failure_rate = k6.get('failure_rate', 0)
                success_rate = 100.0 - failure_rate
                f.write(f"  • Taxa de sucesso: {success_rate:.2f}%\n")
                f.write(f"  • Taxa de falha: {failure_rate:.2f}%\n")
                f.write(f"  • VUs máximos: {k6.get('max_vus', 0)}\n")
                f.write(f"  • Iterações: {k6.get('iterations', 0):,}\n\n")
            
            if 'hpa' in data and data['hpa']['post']:
                f.write("🔄 Autoscaling (HPA):\n")
                for service, hpa_data in data['hpa']['post'].items():
                    f.write(f"  • {service}: {hpa_data.get('replicas', 0)} réplicas\n")
                f.write("\n")
            
            if 'pods' in data and data['pods']['post']:
                f.write("💻 Uso de Recursos:\n")
                for service, pod_data in data['pods']['post'].items():
                    if 'avg_cpu' in pod_data:
                        f.write(f"  • {service}:\n")
                        f.write(f"      CPU: {pod_data['avg_cpu']:.0f}m\n")
                        f.write(f"      Memory: {pod_data['avg_memory']:.0f}Mi\n")
        
        f.write("\n" + "═" * 70 + "\n")
        f.write("  FIM DO RELATÓRIO\n")
        f.write("═" * 70 + "\n")
    
    print(f"✅ Relatório salvo: {report_path}")

def main():
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  Análise de Resultados - Testes de Observabilidade K8s      ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print()
    
    print("📁 Coletando métricas...")
    metrics = collect_all_metrics()
    
    if not metrics:
        print("❌ Nenhuma métrica encontrada!")
        print("   Execute os testes primeiro: ./scripts/run_all_tests.sh")
        return
    
    print(f"✅ Métricas coletadas de {len(metrics)} cenário(s)")
    print()
    
    print("📊 Gerando gráficos...")
    plot_latency_comparison(metrics)
    plot_throughput_comparison(metrics)
    plot_success_rate(metrics)
    plot_hpa_scaling(metrics)
    plot_resource_usage(metrics)
    plot_latency_percentiles(metrics)
    
    print()
    print("📝 Gerando relatório resumido...")
    generate_summary_report(metrics)
    
    print()
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  ✅ Análise concluída com sucesso!                          ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print()
    print(f"📂 Gráficos salvos em: {PLOTS_DIR}/")
    print()
    print("Gráficos gerados:")
    for plot_file in sorted(PLOTS_DIR.glob("*.png")):
        print(f"  • {plot_file.name}")
    print()

if __name__ == "__main__":
    main()
