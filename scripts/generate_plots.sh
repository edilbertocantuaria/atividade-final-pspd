#!/bin/bash
# Script para gerar gráficos de um cenário específico após testes finalizados
# Uso: ./scripts/generate_plots.sh <número_do_cenário>
# Exemplo: ./scripts/generate_plots.sh 1

set -e

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Geração de Gráficos - Cenário Específico              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar argumento
if [ -z "$1" ]; then
    echo -e "${RED}❌ Erro: Número do cenário não especificado!${NC}"
    echo ""
    echo -e "${YELLOW}Uso:${NC}"
    echo "  ./scripts/generate_plots.sh <número_do_cenário>"
    echo ""
    echo -e "${YELLOW}Exemplos:${NC}"
    echo "  ./scripts/generate_plots.sh 1    # Gera plots do cenário 1"
    echo "  ./scripts/generate_plots.sh 2    # Gera plots do cenário 2"
    echo "  ./scripts/generate_plots.sh 3    # Gera plots do cenário 3"
    echo ""
    echo -e "${YELLOW}Cenários disponíveis:${NC}"
    ls -d test_results/scenario_* 2>/dev/null | sed 's|test_results/scenario_||' | sort -n | while read num; do
        echo "  • Cenário $num"
    done
    exit 1
fi

SCENARIO_NUM=$1
RESULTS_DIR="test_results/scenario_${SCENARIO_NUM}"
PLOTS_DIR="${RESULTS_DIR}/plots"

# Verificar se o diretório do cenário existe
if [ ! -d "$RESULTS_DIR" ]; then
    echo -e "${RED}❌ Erro: Cenário $SCENARIO_NUM não encontrado!${NC}"
    echo ""
    echo -e "${YELLOW}Diretório esperado:${NC} $RESULTS_DIR"
    echo ""
    echo -e "${YELLOW}Cenários disponíveis:${NC}"
    ls -d test_results/scenario_* 2>/dev/null | sed 's|test_results/scenario_||' | sort -n | while read num; do
        echo "  • Cenário $num"
    done
    exit 1
fi

echo -e "${BLUE}📁 Cenário:${NC} $SCENARIO_NUM"
echo -e "${BLUE}📂 Diretório:${NC} $RESULTS_DIR"
echo ""

# Verificar se há resultados de testes
TESTS_FOUND=0
for test in baseline ramp spike soak; do
    if [ -f "${RESULTS_DIR}/${test}/output.txt" ]; then
        TESTS_FOUND=$((TESTS_FOUND + 1))
        echo -e "${GREEN}✓${NC} Teste ${test} encontrado"
    else
        echo -e "${YELLOW}⚠${NC} Teste ${test} não encontrado"
    fi
done

echo ""

if [ $TESTS_FOUND -eq 0 ]; then
    echo -e "${RED}❌ Erro: Nenhum resultado de teste encontrado!${NC}"
    echo ""
    echo -e "${YELLOW}Execute os testes primeiro:${NC}"
    echo "  cd test/scenario_${SCENARIO_NUM}"
    echo "  ./run_all.sh"
    exit 1
fi

echo -e "${GREEN}✓ ${TESTS_FOUND} teste(s) encontrado(s)${NC}"
echo ""

# Criar diretório de plots se não existir
mkdir -p "$PLOTS_DIR"

# Verificar dependências Python
echo -e "${BLUE}🔍 Verificando dependências...${NC}"
if ! python3 -c "import matplotlib" 2>/dev/null; then
    echo -e "${YELLOW}⚠ matplotlib não encontrado. Instalando...${NC}"
    pip3 install matplotlib --quiet
fi

echo -e "${GREEN}✓ Dependências OK${NC}"
echo ""

# Executar script de análise
echo -e "${BLUE}📊 Gerando gráficos...${NC}"
echo ""

python3 scripts/analyze_results.py "$RESULTS_DIR"

echo ""
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ Gráficos gerados com sucesso!                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${GREEN}📂 Gráficos salvos em:${NC} ${PLOTS_DIR}/"
echo ""

# Listar gráficos gerados
if [ -d "$PLOTS_DIR" ]; then
    PNG_COUNT=$(ls -1 "${PLOTS_DIR}"/*.png 2>/dev/null | wc -l)
    if [ $PNG_COUNT -gt 0 ]; then
        echo -e "${BLUE}Gráficos gerados (${PNG_COUNT}):${NC}"
        ls -1 "${PLOTS_DIR}"/*.png | while read file; do
            basename "$file"
        done | sort | nl -w2 -s'. '
        echo ""
    fi
    
    # Verificar relatório
    if [ -f "${PLOTS_DIR}/SUMMARY_REPORT.txt" ]; then
        echo -e "${BLUE}📄 Relatório:${NC} SUMMARY_REPORT.txt"
        echo ""
    fi
fi

# Verificar se há múltiplos cenários para comparação
SCENARIO_COUNT=$(ls -d test_results/scenario_* 2>/dev/null | wc -l)

if [ "$SCENARIO_COUNT" -ge 2 ]; then
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Comparação de Cenários                                      ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}📊 Detectados $SCENARIO_COUNT cenários com resultados${NC}"
    echo ""
    
    # Perguntar se quer gerar comparação
    echo -n -e "${YELLOW}Deseja gerar análise comparativa entre cenários? (S/n):${NC} "
    read -r COMPARE_RESPONSE
    
    if [[ ! "$COMPARE_RESPONSE" =~ ^[Nn]$ ]]; then
        echo ""
        echo -e "${BLUE}🔄 Gerando análise comparativa...${NC}"
        echo ""
        
        if python3 scripts/compare_scenarios.py; then
            echo ""
            echo -e "${GREEN}✅ Análise comparativa gerada com sucesso!${NC}"
            echo -e "${GREEN}📂 Resultados em:${NC} test_results/scenario-comparison/"
            echo ""
        else
            echo ""
            echo -e "${YELLOW}⚠️  Erro ao gerar análise comparativa${NC}"
            echo ""
        fi
    fi
fi

echo ""
echo -e "${YELLOW}💡 Dicas:${NC}"
echo "  • Visualizar gráficos: xdg-open ${PLOTS_DIR}/"
echo "  • Ver relatório: cat ${PLOTS_DIR}/SUMMARY_REPORT.txt"
if [ "$SCENARIO_COUNT" -ge 2 ]; then
    echo "  • Ver comparação: cat test_results/scenario-comparison/SCENARIO_COMPARISON_REPORT.txt"
fi
echo ""

# Perguntar se quer abrir os gráficos
if command -v xdg-open &> /dev/null; then
    echo -n -e "${YELLOW}Deseja abrir o diretório de gráficos? (s/N):${NC} "
    read -r RESPONSE
    if [[ "$RESPONSE" =~ ^[Ss]$ ]]; then
        xdg-open "$PLOTS_DIR" 2>/dev/null || nautilus "$PLOTS_DIR" 2>/dev/null || echo "Não foi possível abrir o gerenciador de arquivos"
    fi
fi
