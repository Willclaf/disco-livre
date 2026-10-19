# disco-livre 🧹

**Seu Mac nunca mais fica sem espaço do nada.**

O `disco-livre` mostra o que está comendo o seu disco (inclusive as pastas que o Finder esconde), limpa só o que é lixo de verdade e fica de olho em segundo plano. Quando o espaço livre fica abaixo da sua meta, ele te avisa.

Ele funciona sozinho, direto no Terminal. E também vem com uma **skill pro Claude Code e pro Codex**: é só falar "meu Mac tá sem espaço" que a IA roda a análise e te explica tudo em português.

---

## Por que isso existe

Num dia normal, o Mac ficou com **9 GB livres de 228 GB**. Os culpados:

- **16 GB de relatórios de crash.** Um app entrou em loop e gerou quase 200 mil arquivos em 3 dias, numa pasta que ninguém vê.
- **A pasta "Filmes" pesava 4 GB e aparecia vazia.** Eram stills do DaVinci Resolve guardados numa pasta oculta.
- **8 GB de cache do Lightroom** no SSD.
- **"Meu Chrome perdeu todos os perfis."** Uma automação instalou uma tarefa que abria um Chrome separado e reabria ele toda vez que era fechado. Os perfis estavam lá, intactos.

Em uma tarde voltaram **mais de 35 GB** sem apagar nada importante. Esta ferramenta é tudo isso empacotado, pra não acontecer de novo.

---

## Instalar

### Jeito mais fácil: baixar o instalador (.dmg)

1. Baixe **[DiscoLivre.dmg](https://github.com/Willclaf/disco-livre/releases/latest/download/DiscoLivre.dmg)**
2. Abra o arquivo e **arraste o Disco Livre pra pasta Aplicativos**
3. Abra o Disco Livre. Na primeira vez, o Mac pode dizer que não verificou o desenvolvedor: vá em **Ajustes do Sistema → Privacidade e Segurança → Abrir Mesmo Assim** (no macOS 13/14: botão direito no app → Abrir)
4. Pronto: ele se instala sozinho, aparece na barra de menus e já mostra quanto espaço escondido encontrou

### Jeito fácil: pela sua IA

Abra o Claude Code, o Codex ou o Cursor e cole:

> Instale o disco-livre pra mim: https://github.com/Willclaf/disco-livre — siga o AGENTS.md do repositório.

A IA baixa o projeto, pergunta a sua meta de espaço, instala tudo e confere se funcionou. Você só aprova o que ela pedir.

### Jeito manual: uma linha no Terminal

```bash
zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Willclaf/disco-livre/main/instalar.sh)"
```

Não precisa de git nem de nenhuma ferramenta da Apple: o app vem pronto (e é conferido por SHA-256 antes de instalar). O instalador pergunta a sua meta de espaço livre e, no fim, **o Disco Livre abre a análise geral do seu Mac**.

Pra instalar sem perguntas: `… instalar.sh)" -- --sim --meta 30 --vigia sim --auto-limpeza nao`

Requisitos: macOS 13 (Ventura) ou mais novo, Intel ou Apple Silicon.

---

## A primeira análise: o espaço que estava escondido

Logo depois de instalar, o Disco Livre vasculha o Mac e mostra **quanto dá pra liberar**:

- **Seguro** (já vem marcado): caches de navegador, de apps (Claude, Codex, Cursor, Slack, Figma…), de programação (npm, pip, uv…), do Lightroom, relatórios de crash, logs velhos, atualizações já baixadas
- **Revise** (só sai se você marcar, e vai pra Lixeira): instaladores .dmg/.pkg esquecidos em Downloads, conversas antigas do Codex, modelos de IA baixados, navegadores do Playwright
- O que está **em uso** aparece com cadeado: "feche o Chrome pra limpar". Fechou? É só clicar em **conferir de novo**.

Você escolhe, clica em **Liberar** e vê: **🎉 Você liberou X GB que estavam escondidos.** O que foi pra Lixeira aparece separado, com um botão pra esvaziar.

Dá pra rodar de novo quando quiser: no app (**Ver mais → Fazer análise geral**) ou no Terminal (`disco-livre geral`).

---

## O app da barra de menus

Um ícone pequeno de disco mostra quantos GB você tem livres. **Passou o mouse, abre o resumo. Tirou, fecha.** Se clicar, ele fica aberto até você clicar fora.

O resumo mostra só quatro coisas:

| | |
|---|---|
| 🟢 **Espaço livre** | anel colorido (verde, laranja ou vermelho) com um tique marcando a sua meta |
| 🚩 **Meta** | − / + pra ajustar quantos GB livres você quer manter |
| 👁 **Vigia** | liga e desliga a vigilância automática |
| ✨ **Pra limpar** | quanto lixo seguro existe, com o botão **Limpar** |

O **Ver mais** abre os detalhes: alertas (app crashando, tarefa que reabre app sozinha, com botão **Pausar**), o que exatamente dá pra limpar, as maiores pastas (inclusive as ocultas) e os ajustes.

Quando o espaço livre fica abaixo da meta, o ícone fica vermelho.

---

## Usar no Terminal

```bash
disco-livre                     # resumo: espaço livre, meta, vigilância
disco-livre geral               # análise geral: acha o espaço escondido, você escolhe o que limpar
disco-livre analisar            # raio-x completo
disco-livre limpar              # mostra o lixo seguro (só simula)
disco-livre limpar --executar   # apaga o lixo seguro (pede confirmação)
disco-livre esvaziar-lixeira    # esvazia a Lixeira (pede confirmação)
disco-livre atualizar           # instala a versão mais nova (mantém suas configurações)
disco-livre mover <pasta> <HD>  # manda uma pasta pro HD externo e deixa um atalho
```

### O raio-x (`disco-livre analisar`)

```
1. Lixo seguro (é recriado sozinho)
  948 MB    Logs com mais de 7 dias
  8.5 GB    Cache do Chrome (feche o app pra limpar)
  8.0 GB    Cache do Camera Raw (Lightroom/Photoshop)
  Total: 10.9 GB

2. Apps crashando em massa
  ✗ Codex gerou 194975 relatórios de crash (16.0 GB)

3. Maiores pastas pra revisar
  10.7 GB   ~/.lmstudio (oculta no Finder)
            ↳ Modelos de IA locais. Apague os que não usa ou mova pro HD externo
  3.4 GB    ~/Movies/.gallery (oculta no Finder)
            ↳ Stills da galeria do DaVinci Resolve. disco-livre mover pro HD externo

4. Tarefas em segundo plano
  ⚠ com.exemplo.chrome abre Google Chrome sozinho e reabre se você fechar

5. Navegadores com controle remoto
  ⚠ Google Chrome está com controle remoto ligado (porta 9222)
```

### Configuração

```bash
disco-livre config                     # ver tudo
disco-livre config meta 30             # espaço livre mínimo (GB)
disco-livre config auto-limpeza sim    # limpar sozinho quando passar da meta
disco-livre config intervalo 3         # vigiar a cada 3 horas
disco-livre ativar / desativar         # liga/desliga a vigilância
```

### A vigilância avisa quando

- o espaço livre fica **abaixo da sua meta**
- o disco perde **mais de 10 GB em 24 h** (algo novo está enchendo)
- um app entra em **loop de crash** (os relatórios são apagados sozinhos)

Tudo o que ele apaga fica anotado em `~/Library/Logs/disco-livre.log`.

### Tarefas em segundo plano

```bash
disco-livre pausar-tarefa com.exemplo.tarefa    # para e não volta ao reiniciar
disco-livre religar-tarefa com.exemplo.tarefa   # desfaz
```

---

## O que ele apaga (e o que nunca apaga)

**Apaga só lixo que se recria sozinho:**
relatórios de crash · logs com mais de 7 dias · cache do npm, pip, uv, Yarn e Homebrew · Xcode DerivedData · cache do Chrome, Edge, Brave e Opera GX · cache do Camera Raw · atualizações de apps já baixadas

**Nunca apaga:**
seus arquivos · fotos · projetos · perfis de navegador · modelos de IA · nada fora da sua pasta pessoal

Caches de apps abertos são pulados. Ele pede pra você fechar o app primeiro.
O `mover` só apaga o original depois de conferir que a cópia tem o mesmo número de arquivos e os mesmos bytes.

---

## Skill pro Claude Code / Codex

O `install.sh` copia a skill pra `~/.claude/skills/` e `~/.codex/skills/` (se existirem). Depois disso, é só pedir:

> "Meu Mac tá sem espaço, me ajuda"

A IA roda o raio-x, investiga as pastas estranhas, explica o que é cada coisa e **pede sua permissão** antes de mexer em qualquer coisa.

---

## ☕ Apoie

<a id="apoie"></a>

O Disco Livre é **grátis e vai continuar grátis**. Se ele te ajudou, me paga um café: um Pix de qualquer valor me ajuda a manter e melhorar o projeto. 💚

<img src="assets/pix-qr.png" alt="QR Code Pix" width="200">

**Pix Copia e Cola:**
```
00020126580014br.gov.bcb.pix0136c6a0d335-775a-4a2e-bb7a-2dfbf3f2cb675204000053039865802BR5912WILLIAN CLAF6014SANTA CATARINA62070503***6304C34D
```
Chave Pix: `c6a0d335-775a-4a2e-bb7a-2dfbf3f2cb67` · Willian Claf

Também dá pra apoiar pelo app (☕ no rodapé) ou no Terminal: `disco-livre apoiar`.

---

## Desinstalar

O Disco Livre deixa uma "vigilância" rodando em segundo plano (ela confere seu espaço de tempos em tempos). Por isso, **só arrastar o app pra Lixeira não basta**: a vigilância continua e o macOS pode seguir pedindo permissões. Escolha um jeito:

**1. Pelo app (mais fácil)**
Clique no ícone da barra de cima › **Ajustes** › **Desinstalar o Disco Livre…**

**2. Pelo Terminal (funciona mesmo se você já apagou o app)**
Abra o app **Terminal**, cole esta linha e aperte Enter:

```bash
zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Willclaf/disco-livre/main/uninstall.sh)"
```

Ela remove o app, a vigilância, o comando `disco-livre`, as configurações e as permissões que o macOS tinha guardado. Não desfaz nada que ele já limpou.

**3. Já apaguei o app e fiquei com a vigilância**
A partir da versão 1.4.1 ela percebe sozinha que o app sumiu e se remove na próxima verificação (até 3 horas). Se não quiser esperar, use o jeito 2.

---

## Atualizar

O app avisa quando sai versão nova (botão **⬆️** no rodapé) e a vigilância manda uma notificação. É só clicar, ou rodar `disco-livre atualizar`. Suas configurações ficam como estão.

Quem tem a versão 1.0 ou 1.1 precisa rodar o comando de instalação de novo uma vez. Daí pra frente, a atualização é com um clique.

Licença MIT. Feito com raiva de "Dados do Sistema: 63 GB". 😤
