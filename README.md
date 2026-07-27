# ⚔️ Gothibia — Custom Tibia Project

<p align="center">
  <img src="https://img.shields.io/badge/Status-Em%20Desenvolvimento-blue?style=for-the-badge" alt="Status">
  <img src="https://img.shields.io/badge/Prop%C3%B3sito-Estudo%20%26%20Aprendizado-green?style=for-the-badge" alt="Propósito">
  <img src="https://img.shields.io/badge/Linguagens-C%2B%2B20%20%7C%20Lua-orange?style=for-the-badge" alt="Linguagens">
</p>

---

## 🎯 Sobre o Projeto & Objetivos

**Gothibia** é um projeto de desenvolvimento de Open Tibia Server (OTServer) e Client totalmente customizado, criado com o objetivo principal de **estudo e aprendizado contínuo** em engenharia de software, desenvolvimento de jogos 2D, sistemas distribuídos e arquitetura de código em **C++** e **Lua**.

O objetivo final deste projeto vai muito além de um servidor tradicional de Tibia: a meta é transformar a base do motor em um **jogo completamente novo**, trazendo **mecânicas inovadoras**, novos sistemas de combate, interface reformulada e conteúdo original.

### 🚀 Principais Metas:
- 📚 **Aprendizado Prático**: Estudar o funcionamento interno de engines de jogos multiplayer, manipulação de pacotes de rede, renders gráficos 2D e orientação a objetos em C++20 e Lua.
- 🧙‍♂️ **Mecânicas Inovadoras**: Criar novos sistemas de vocações, árvore de habilidades, reformulação de combate e elementos de RPG modernos.
- 🎨 **Interface Customizada**: Expandir as capacidades do cliente (OTClient) criando módulos visuais inéditos, HUDs dinâmicas e menus intuitivos.
- 🛠️ **Arquitetura & Clean Code**: Manter um padrão rígido de organização de código, boas práticas de commit (Conventional Commits) e compilação multiplataforma.

---

## 📂 Estrutura do Repositório

O repositório é organizado em três componentes principais:

```bash
Custom-Tibia/
├── 📁 Server/
│   └── 📁 canary/                 # Engine do Servidor (C++20 & Scripts Lua)
├── 📁 Client/
│   └── 📁 otclient/               # Cliente do Jogo (C++ & Módulos Lua/OTUI)
├── 📁 Assets/
│   └── 📁 Assets-Editor-main/     # Utilitários e Editores de Sprites/Assets
└── 📄 .gitignore                  # Regras de descarte de arquivos binários e temporários
```

### 1. ⚙️ Server (`Server/canary`)
Baseado no motor **Canary**, o servidor é responsável pela lógica do mundo, cálculo de atributos, gerenciamento de banco de dados (MySQL/SQLite), movimentação, mapas e execução de scripts em Lua.

### 2. 💻 Client (`Client/otclient`)
Baseado no **OTClient**, a aplicação cliente cuida da renderização gráfica em OpenGL/DirectX, reprodução de áudio, interface do usuário (UI) e comunicação por socket com o servidor.

### 3. 🎨 Assets (`Assets/`)
Contém ferramentas e recursos visuais para edição de mapas, sprites, arquivos `.dat` e `.spr`.

---

## 🛠️ Tecnologias Utilizadas

- **C++20**: Núcleo de alta performance do Servidor e Cliente.
- **Lua / LuaJIT**: Linguagem de scripting para regras de jogo, eventos, feitiços e módulos de interface.
- **CMake & MSVC**: Ferramenta de build e compilação para Windows/Linux.
- **MySQL / MariaDB**: Banco de dados relacional para persistência de jogadores e mundo.
- **OpenGL**: Renderização de sprites 2D do cliente.

---

## 💻 Pré-requisitos & Compilação

### Requisitos Básicos:
- **Compilador C++**: Visual Studio 2022 (MSVC) no Windows ou GCC/Clang no Linux.
- **CMake**: Versão 3.22 ou superior.
- **vcpkg**: Gerenciador de pacotes de dependências C++.
- **MySQL Server**: Para gerenciamento da base de dados do jogo.

### Compilando o Servidor (Canary) via CMake Presets (Windows):
```bat
cd Server/canary
cmake --preset windows-release
cmake --build --preset windows-release --target canary
```

---

## 📜 Convenções de Código & Commits

Para garantir um repositório organizado e fácil de manter, adotamos o padrão **Conventional Commits**:

- `feat:` Nova funcionalidade ou mecânica adicionada.
- `fix:` Correção de bug no servidor ou cliente.
- `perf:` Melhoria no desempenho de execução ou renderização.
- `refactor:` Reformulação de código sem alterar o comportamento externo.
- `docs:` Alterações na documentação (`README.md`, guias, etc.).
- `chore:` Atualizações de build, dependências ou manutenção geral.

---

## ⚖️ Licença e Aviso Legal

Este é um projeto **educacional e sem fins lucrativos**. Todas as alterações, novos sistemas e códigos desenvolvidos neste repositório têm caráter exclusivo de aprendizado pessoal e pesquisa técnica.

---

<p align="center">
  Desenvolvido por <b>YaanMark</b> 🚀
</p>
