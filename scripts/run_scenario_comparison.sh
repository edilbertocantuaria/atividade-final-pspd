#!/bin/bash
# Script para executar todos os cenários e gerar análise comparativa

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Executando Todos os Cenários                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Executar cada cenário
for i in {1..5}; do
    echo "═══════════════════════════════════════════════════════════════"
    echo "  CENÁRIO $i/5"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    if [ -f "$PROJECT_DIR/test/scenario_$i/run_all.sh" ]; then
        "$PROJECT_DIR/test/scenario_$i/run_all.sh" || echo -e "${YELLOW}⚠️  Cenário $i falhou${NC}"
    else
        echo -e "${YELLOW}⚠️  Script não encontrado: test/scenario_$i/run_all.sh${NC}"
    fi
    
    echo ""
    [ "$i" != "5" ] && sleep 10
done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  📊 Gerando Análise Comparativa                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Gerar comparação
python3 "$SCRIPT_DIR/compare_scenarios.py"

echo ""
echo -e "${GREEN}✅ Todos os cenários executados e comparados!${NC}"
echo ""
echo "📁 Resultados em: test_results/"
echo "�� Comparação em: test_results/scenario-comparison/"
