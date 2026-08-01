# Profession System
**Versão:** 1.0

## Objetivo

Implementar um sistema completo de profissões para o servidor Canary inspirado nas profissões do World of Warcraft.

O sistema deve ser totalmente orientado a dados (Data Driven), onde toda configuração seja realizada através de arquivos `.lua`, evitando qualquer necessidade de recompilar o servidor ao adicionar ou modificar conteúdo.

---

# Objetivos

O sistema deverá possuir dois grandes grupos de profissões.

## Profissões de Coleta

São responsáveis por coletar recursos do mundo.

Exemplos:

- Mining
- Herbalism
- Fishing
- Skinning

---

## Profissões de Craft

São responsáveis por transformar materiais em novos itens.

Exemplos:

- Blacksmith
- Alchemy
- Tailoring
- Engineering
- Jewelcrafting

---

# Requisitos Gerais

Todo o sistema deve ser configurado exclusivamente por arquivos Lua.

Nenhuma profissão deverá possuir informações fixas em C++.

Todo conteúdo deverá ser carregado automaticamente durante a inicialização do servidor.

Adicionar uma nova profissão deve exigir apenas criar um novo arquivo Lua.

---

# Estrutura de Pastas

```
data/
    professions/

        config.lua

        loader.lua

        experience.lua

        gathering/

        crafting/

        nodes/

        recipes/

        tools/
```

---

# Configuração Global

Arquivo:

```
config.lua
```

Responsável por definir:

- nível máximo da profissão
- quantidade máxima de profissões
- quantidade máxima de profissões de coleta
- quantidade máxima de profissões de craft
- curva de experiência
- habilitar especializações
- habilitar qualidade de itens
- habilitar craft crítico

Exemplo:

```lua
ProfessionConfig = {

    maxLevel = 100,

    maxGathering = 2,

    maxCrafting = 2,

    enableSpecializations = true,

    enableCriticalCraft = true,

    enableItemQuality = true

}
```

---

# Loader

Arquivo

```
loader.lua
```

Responsável por:

- carregar todas profissões
- carregar todas receitas
- carregar todos nodes
- carregar todas ferramentas

O loader deve procurar automaticamente todos os arquivos existentes.

Não deverá existir lista manual de arquivos.

---

# Definição de Profissão

Cada profissão deve possuir um arquivo próprio.

Exemplo:

```
gathering/mining.lua
```

Campos obrigatórios:

```lua
Profession = {

    id = "mining",

    name = "Mining",

    category = "gathering",

    icon = 1,

    maxLevel = 100,

    tool = "pickaxe"

}
```

Campos opcionais:

- descrição
- efeitos visuais
- animações
- sons
- buffs
- especializações

---

# Dados do Jogador

Cada jogador deve possuir dados independentes para cada profissão.

Cada profissão deve armazenar:

- nível
- experiência
- receitas aprendidas
- especialização
- estatísticas

Exemplo:

```
Mining

Level

Experience

Recipes

Statistics
```

---

# Sistema de Experiência

A experiência deverá ser configurada em:

```
experience.lua
```

Exemplo:

```lua
ProfessionExperience = {

    [1] = 100,
    [2] = 150,
    [3] = 220

}
```

O servidor deverá utilizar essa tabela para calcular evolução.

---

# Sistema de Coleta

Cada recurso existente no mapa será um Node.

Exemplo:

- Copper Vein
- Iron Vein
- Gold Vein

Cada Node deverá possuir:

- profissão necessária
- nível necessário
- tempo de coleta
- respawn
- experiência
- drops
- ferramenta necessária

Exemplo:

```lua
Node = {

    id = "copper",

    profession = "mining",

    requiredLevel = 1,

    gatherTime = 5,

    respawn = 300,

    experience = 15,

    tool = "pickaxe"

}
```

---

# Sistema de Drops

Cada Node poderá possuir diversos drops.

Exemplo:

```lua
drops = {

    {
        item = 2145,
        chance = 100,
        amount = {1,3}
    },

    {
        item = 2150,
        chance = 5,
        amount = 1
    }

}
```

O sistema deverá escolher os drops utilizando porcentagem.

---

# Sistema de Ferramentas

Todas ferramentas deverão ser configuráveis.

Exemplo:

```
tools.lua
```

```lua
Tool = {

    id = "pickaxe",

    itemid = 2553,

    quality = 1

}
```

No futuro será possível possuir diversas qualidades.

Exemplo

- Wooden
- Iron
- Steel
- Mithril
- Legendary

Cada qualidade poderá modificar:

- velocidade
- chance crítica
- chance rara
- durabilidade

---

# Sistema de Receitas

Cada receita deverá possuir um arquivo próprio.

Exemplo:

```
recipes/blacksmith/iron_sword.lua
```

Campos obrigatórios:

```lua
Recipe = {

    id = "iron_sword",

    profession = "blacksmith",

    requiredLevel = 15,

    craftTime = 5,

    experience = 40

}
```

Ingredientes:

```lua
ingredients = {

    {
        item = 2145,
        count = 5
    },

    {
        item = 2148,
        count = 2
    }

}
```

Resultado:

```lua
result = {

    item = 2376,

    amount = 1

}
```

---

# Sistema de Aprendizado

Receitas poderão ser aprendidas por:

- nível
- NPC
- livro
- missão
- boss
- evento

O método deverá ser definido na própria receita.

---

# Sistema de Especializações

Cada profissão poderá possuir especializações.

Exemplo:

Blacksmith

↓

Weapon Smith

Armor Smith

Runesmith

Cada especialização poderá liberar receitas exclusivas.

---

# Sistema de Qualidade

Itens produzidos poderão possuir qualidade.

Exemplo

- Common
- Uncommon
- Rare
- Epic
- Legendary

A chance será calculada utilizando:

- nível da profissão
- qualidade da ferramenta
- buffs
- equipamentos

---

# Sistema de Craft Crítico

Durante o craft poderá ocorrer um sucesso crítico.

Exemplos:

- produzir itens extras
- produzir item de qualidade superior
- reduzir consumo de materiais

A chance deverá ser totalmente configurável.

---

# Sistema de Progressão

Cada profissão deverá desbloquear novos conteúdos conforme o nível aumenta.

Exemplo:

Mining

1
Copper

20
Tin

40
Iron

60
Gold

80
Mithril

100
Adamantite

Todos esses desbloqueios deverão ser definidos no arquivo da profissão.

---

# Eventos

O sistema deverá disponibilizar callbacks para futuras integrações.

Eventos mínimos:

```
onProfessionLearn

onProfessionLevelUp

onGatherStart

onGatherSuccess

onGatherFail

onCraftStart

onCraftSuccess

onCraftFail

onCriticalCraft

onRecipeLearn
```

---

# Interface

O módulo deverá fornecer informações para uma interface contendo:

- lista de profissões
- nível
- experiência
- barra de progresso
- receitas
- materiais necessários
- receitas aprendidas
- especialização
- estatísticas

A interface não faz parte desta implementação, apenas a API necessária para alimentá-la.

---

# Persistência

Todas as informações das profissões deverão ser salvas no banco de dados.

Informações mínimas:

- profissão
- nível
- experiência
- especialização
- receitas aprendidas

---

# Requisitos Técnicos

- Implementação modular.
- Totalmente orientada a dados.
- Sem valores hardcoded.
- Compatível com Canary.
- Fácil expansão.
- Suporte a dezenas de profissões.
- Suporte a centenas de receitas.
- Suporte a milhares de nodes de coleta.
- Arquivos Lua carregados automaticamente pelo loader.

---

# Resultado Esperado

Ao concluir a implementação, o servidor deverá permitir:

- Criar novas profissões apenas adicionando arquivos Lua.
- Criar novos recursos de coleta sem alterar código-fonte.
- Criar novas receitas sem recompilar o servidor.
- Configurar toda a progressão das profissões via Lua.
- Integrar facilmente o sistema com NPCs, missões, conquistas, equipamentos e interface do cliente.