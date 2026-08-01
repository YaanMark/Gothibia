# Dungeon System Design Document
## MMORPG Framework para Canary

**Versão:** 1.0

---

# Índice

1. Introdução
2. Objetivos
3. Filosofia de Design
4. Estrutura Geral
5. Fluxo da Dungeon
6. Sistema de Instâncias
7. Sistema de Grupos
8. Escalonamento de Dificuldade
9. Boss Framework
10. IA dos Monstros
11. Sistema de Ameaça (Threat)
12. Eventos Dinâmicos
13. Puzzles
14. Objetivos
15. Loot
16. Dungeon Journal
17. Matchmaking
18. Mythic+
19. Banco de Dados
20. Alterações no Canary
21. APIs Lua
22. Roadmap

---

# 1. Introdução

Este documento descreve completamente o sistema de Dungeons desenvolvido para um MMORPG baseado no Canary.

O objetivo é criar um sistema moderno inspirado em MMORPGs como:

- World of Warcraft
- Final Fantasy XIV
- Guild Wars 2
- Lost Ark
- Elder Scrolls Online

Porém adaptado ao gameplay do Tibia.

O sistema foi projetado para ser modular.

Isso significa que novas dungeons poderão ser criadas sem alterar o código principal do servidor.

Todo o sistema deverá funcionar através de módulos independentes.

---

# 2. Objetivos

O sistema possui cinco objetivos principais.

## 2.1 Replay

A dungeon nunca deve parecer exatamente igual.

Cada entrada deve oferecer pequenas diferenças.

Exemplos:

- monstros diferentes
- eventos diferentes
- clima diferente
- mini boss diferente
- loot diferente

---

## 2.2 Cooperação

A dungeon deve incentivar grupos.

O jogador sozinho consegue completar algumas dungeons.

Porém grupos terão vantagens.

Exemplos:

- puzzles cooperativos
- bosses com mecânicas
- alavancas simultâneas
- divisão de funções

---

## 2.3 Progressão

A dungeon deve fazer parte da evolução do personagem.

Ela fornecerá:

- equipamentos
- materiais
- moedas
- reputação
- cosméticos
- montarias
- pets
- relíquias

---

## 2.4 Escalabilidade

Todo conteúdo deverá funcionar para:

1 jogador

2 jogadores

3 jogadores

5 jogadores

10 jogadores

Sem necessidade de criar versões diferentes.

---

## 2.5 Expansibilidade

O desenvolvedor deve conseguir criar uma dungeon inteira apenas adicionando novos arquivos.

Sem modificar o Core.

---

# 3. Filosofia de Design

Uma dungeon NÃO é apenas um mapa cheio de monstros.

Ela é uma aventura.

Cada dungeon deve contar uma história.

Cada sala possui um propósito.

Cada boss possui uma identidade.

Cada recompensa possui significado.

O jogador deve sentir que está explorando um lugar vivo.

---

# 4. Estrutura Geral

O sistema será dividido em módulos.

DungeonManager

↓

DungeonTemplate

↓

DungeonInstance

↓

DungeonState

↓

DungeonEvent

↓

BossController

↓

LootController

↓

RewardController

↓

ThreatManager

↓

DifficultyManager

↓

DungeonJournal

Cada módulo possui apenas uma responsabilidade.

---

# 5. Fluxo Geral

O fluxo completo da dungeon será:

Selecionar Dungeon

↓

Entrar na Fila

↓

Criar Grupo

↓

Verificar Requisitos

↓

Criar Instância

↓

Teleportar Jogadores

↓

Iniciar Dungeon

↓

Eventos

↓

Mini Boss

↓

Checkpoint

↓

Novo Evento

↓

Boss Final

↓

Baú

↓

Recompensas

↓

Encerrar Instância

↓

Remover Instância da Memória

---

# 6. Sistema de Instâncias

Este é o coração do sistema.

Cada grupo recebe uma cópia exclusiva da dungeon.

Exemplo:

Grupo A

↓

Dungeon #154

Grupo B

↓

Dungeon #155

Grupo C

↓

Dungeon #156

Nenhum grupo interfere no outro.

---

Cada instância armazena:

- jogadores
- monstros vivos
- bosses derrotados
- portas abertas
- puzzles resolvidos
- eventos ativos
- tempo restante
- loot disponível
- checkpoints

Quando o último jogador sair:

↓

A instância será destruída.

---

# 7. Dungeon Template

O Template representa a dungeon original.

Exemplo:

Crypt of Blood

Contém:

Mapa

Bosses

Eventos

Loot

NPCs

Puzzles

Música

Iluminação

Objetivos

Quando uma instância é criada:

Template

↓

Clone

↓

DungeonInstance

Assim nenhuma alteração afeta a dungeon original.

---

# 8. Sistema de Grupos

Cada grupo possui:

Leader

Tank

Healer

DPS

Support

As funções são opcionais.

Porém determinadas mecânicas podem exigir um grupo balanceado.

---

O grupo também possui:

PartyID

DungeonID

Difficulty

LootMode

ReadyState

AverageLevel

GearScore

PowerLevel

Essas informações serão utilizadas pelo escalonamento.

---

# 9. Escalonamento de Dificuldade

Este é um dos sistemas mais importantes.

A dificuldade nunca será fixa.

Ela será calculada dinamicamente.

Os fatores utilizados são:

Quantidade de jogadores

Nível médio

Gear Score

Poder total

Classe dos jogadores

Quantidade de curandeiros

Quantidade de tanques

Quantidade de DPS

---

Exemplo:

Grupo

Jogador 1

Lv 100

GS 500

Jogador 2

Lv 98

GS 480

Jogador 3

Lv 105

GS 540

Jogador 4

Lv 102

GS 510

↓

Power Level

2040

O Difficulty Manager utiliza esse valor.

---

Escalonamento:

HP

Ataque

Defesa

Velocidade

Quantidade de monstros

Quantidade de elites

Quantidade de eventos

Número de fases

Novas habilidades

Chance de Boss Secreto

Loot

Tudo será ajustado automaticamente.

---

Jamais aumentar apenas HP.

Isso gera lutas cansativas.

Prefira adicionar novas mecânicas.

Exemplo:

Grupo pequeno

Boss possui:

Golpe

Invocação

Grupo médio

Boss ganha:

Nova fase

Nova magia

Grupo grande

Boss ganha:

Enrage

Área nova

Eventos

Mini Boss adicional

Invocações especiais

A luta muda completamente.

---

# 10. Boss Framework

O Boss Framework será um sistema modular que permitirá criar qualquer chefe apenas por configuração e scripts, sem alterar o Core do Canary.

Cada chefe será tratado como uma entidade especial com uma máquina de estados (State Machine).

## Estrutura

```
Boss
│
├── BossData
├── BossState
├── BossPhase
├── BossSkill
├── BossEvent
├── ThreatManager
├── SpawnController
├── LootController
└── AchievementController
```

Cada módulo possui apenas uma responsabilidade.

---

## BossData

Armazena informações permanentes.

Exemplo:

- Nome
- ID
- Dungeon
- Aparência
- Música
- Lore
- Nível recomendado
- Dificuldade
- Loot Table
- Fases

Esses dados nunca mudam durante a luta.

---

## BossState

Representa o estado atual.

Exemplo:

```
Idle

↓

Combat

↓

Phase 2

↓

Enrage

↓

Dead
```

O Boss nunca executa duas fases simultaneamente.

---

## Sistema de Fases

Cada fase é ativada por condições.

Exemplos:

- HP abaixo de 80%
- HP abaixo de 50%
- HP abaixo de 20%
- Tempo de luta
- Morte de um NPC
- Puzzle resolvido
- Todos os cristais destruídos

Exemplo:

### Fase 1

100% até 70%

Ataques básicos.

Invoca morcegos.

---

### Fase 2

70% até 35%

Escurece a sala.

Invoca sombras.

Ativa novas habilidades.

---

### Fase 3

35%

Entra em Frenesi.

Aumenta velocidade.

Ativa todas as habilidades.

---

# Sistema de Habilidades

Cada habilidade possui:

```
SkillID

Nome

Cooldown

Cast Time

Alcance

Área

Prioridade

Condição

Animação

Efeito

Dano

Tempo de reutilização
```

Assim qualquer habilidade pode ser reutilizada por outros chefes.

---

## Tipos de habilidades

### Direcionadas

Selecionam um jogador.

Exemplos

- Flecha
- Bola de fogo
- Maldição

---

### Área

Atacam regiões.

Exemplo

```
□□□□□
□■■■□
□■■■□
□■■■□
□□□□□
```

---

### Cone

Muito utilizadas por dragões.

```
    ■
   ■■■
  ■■■■■
 ■■■■■■■
```

---

### Linha

```
■■■■■■■■
```

---

### Global

Afetam toda a arena.

Exemplo

Tempestade.

---

## Sistema de Prioridade

Nem todas as habilidades podem acontecer ao mesmo tempo.

Cada uma possui prioridade.

Exemplo

| Prioridade | Uso |
|------------|-----|
| 1 | Ataques básicos |
| 2 | Invocações |
| 3 | Mecânicas |
| 4 | Transição de fase |
| 5 | Ultimate |

Quando uma habilidade prioridade 5 iniciar, todas inferiores podem ser interrompidas.

---

# Arena Controller

Cada boss controla sua arena.

Pode:

- Fechar portas
- Abrir portas
- Criar paredes
- Destruir objetos
- Acender tochas
- Escurecer ambiente
- Criar plataformas
- Inundar salas
- Congelar pisos

A arena deixa de ser apenas um mapa.

Ela participa da luta.

---

# Spawn Controller

Controla tudo que é invocado.

Pode criar:

- lacaios
- elites
- objetos
- cristais
- armadilhas
- pilares
- NPCs

Cada invocação possui tempo de vida.

---

# Sistema de Enrage

Caso a luta demore demais.

Exemplo

Após 8 minutos.

O boss recebe:

+50% dano

+30% velocidade

+100% frequência de habilidades

Isso impede grupos de prolongarem a luta indefinidamente.

---

# Bosses Adaptativos

Os chefes podem mudar de comportamento conforme o grupo.

Exemplo

Grupo possui muitos arqueiros.

↓

Boss cria escudos.

Grupo possui muitos magos.

↓

Boss ganha resistência mágica.

Grupo fica agrupado.

↓

Boss usa ataques em área.

Grupo espalhado.

↓

Boss marca jogadores aleatórios.

Essa adaptação torna as lutas mais dinâmicas.

---

# 11. Sistema de Ameaça (Threat System)

O Threat System define quem será atacado.

Não será baseado apenas na distância.

Cada criatura possui uma tabela de ameaça.

```
Boss

↓

Threat Table

↓

Player A = 500

Player B = 900

Player C = 1200

Player D = 200
```

O Boss atacará o Player C.

---

## Fontes de ameaça

### Dano

Quanto mais dano.

Maior ameaça.

---

### Cura

Curar aliados também gera ameaça.

Exemplo

Curou 1000 HP.

↓

+400 Threat

---

### Buffs

Alguns buffs também geram ameaça.

---

### Debuffs

Reduções de defesa.

Silêncio.

Atordoamento.

Tudo pode gerar ameaça.

---

### Taunt

Habilidade exclusiva de tanques.

Ao utilizar.

```
Threat

↓

999999
```

O Boss troca imediatamente de alvo.

---

## Redução de ameaça

Algumas classes poderão reduzir seu nível de ameaça.

Exemplo

Assassino.

Utiliza Furtividade.

↓

Threat reduzido em 70%.

---

# Atualização da Threat Table

A tabela será atualizada constantemente.

Eventos:

- causar dano
- curar
- morrer
- reviver
- entrar na luta
- sair da arena

---

# Reset de ameaça

Pode ocorrer quando:

- Boss muda de fase
- Jogador morre
- Jogador sai da arena
- Habilidade especial

---

# Interface de Threat

Opcionalmente.

O OTClient poderá mostrar:

```
Tank

██████████

Mage

█████

Archer

███

Healer

██████
```

Assim o jogador sabe quando está prestes a puxar o aggro.

---

# 12. Inteligência Artificial dos Monstros

Os monstros comuns utilizarão uma IA modular.

Cada criatura será composta por comportamentos.

```
Monster AI

│

├── Patrol

├── Chase

├── Attack

├── Escape

├── Protect

├── Assist

├── Cast

└── Idle
```

Cada comportamento é independente.

---

## Tipos de IA

### Passiva

Nunca inicia combate.

---

### Defensiva

Ataca apenas quando provocada.

---

### Agressiva

Ataca ao entrar no alcance.

---

### Elite

Coordena ataques.

Protege outros monstros.

Recua.

Reposiciona.

Invoca reforços.

---

## Comunicação entre monstros

Monstros próximos poderão compartilhar informações.

Exemplo

Goblin A encontra jogador.

↓

Alerta Goblin B.

↓

Goblin C.

↓

Toda a patrulha entra em combate.

Isso torna o combate muito mais natural do que monstros completamente independentes.

---

# Sistema de Papéis para Inimigos

Cada grupo de monstros pode possuir funções.

- Tanque
- Curandeiro
- Arqueiro
- Mago
- Suporte
- Invocador

Eliminar primeiro o curandeiro ou o invocador passa a ser uma decisão estratégica para o grupo.

---

# IA de Patrulha

Os monstros não precisam permanecer parados.

Eles podem:

- patrulhar corredores;
- vigiar portas;
- investigar sons;
- retornar à posição original após perder o alvo;
- chamar reforços ao encontrar jogadores.

Isso faz com que a dungeon pareça um local vivo e habitado, em vez de apenas um conjunto de criaturas esperando pelo próximo combate.

---

# 13. Sistema de Eventos Dinâmicos

Os Eventos Dinâmicos são responsáveis por tornar cada tentativa da dungeon diferente da anterior.

O jogador nunca deve saber exatamente o que irá acontecer.

O objetivo não é criar aleatoriedade extrema, mas sim aumentar a rejogabilidade.

Cada dungeon possui uma lista de eventos possíveis.

Ao criar uma nova instância, o servidor seleciona quais eventos estarão ativos.

Exemplo:

Dungeon: Catedral Carmesim

Eventos disponíveis:

- Procissão dos Condenados
- Eclipse de Sangue
- Altar Corrompido
- Chuva de Cinzas
- Invasão de Morcegos
- Caçador Vampírico
- Ritual Proibido

Uma partida pode conter apenas três desses eventos.

Outra partida terá combinações diferentes.

---

## Estrutura

```
Dungeon

↓

EventManager

↓

EventPool

↓

Random Selection

↓

Active Events

↓

Reward Bonus
```

---

## Tipos de Eventos

### Ambientais

Alteram a dungeon.

Exemplos

- Neve
- Chuva
- Tempestade
- Escuridão
- Névoa
- Tremor
- Incêndio

---

### Combate

Afetam os monstros.

Exemplos

Todos os vampiros recebem:

+20% Velocidade

Todos os mortos-vivos recebem:

Escudo mágico.

---

### Exploração

Criam novos caminhos.

Exemplo

Uma parede desmorona.

Uma sala secreta aparece.

---

### História

NPCs diferentes aparecem.

Novos diálogos.

Novos objetivos.

---

### Mundo

Eventos extremamente raros.

Exemplo

A Relíquia Escarlate desperta.

↓

Novo Boss aparece.

↓

Novo final da dungeon.

---

# Sistema de Objetivos

Nem toda dungeon precisa ser apenas:

"Mate todos os monstros."

Cada dungeon pode possuir vários objetivos.

---

## Objetivo Principal

Obrigatório.

Exemplo

Derrotar o Lorde Vladreth.

---

## Objetivos Secundários

Opcionais.

Exemplos

Salvar todos os sacerdotes.

↓

Desbloqueia conquista.

---

Destruir todos os altares.

↓

Garante loot extra.

---

Completar em menos de 25 minutos.

↓

Baú adicional.

---

Nenhum jogador morrer.

↓

Título exclusivo.

---

Encontrar sala secreta.

↓

Relíquia.

---

## Objetivos Ocultos

Não aparecem no Journal.

São descobertos pelos jogadores.

Exemplo

Acender todas as tochas.

↓

Boss secreto.

---

# Sistema de Checkpoints

Dungeons longas não devem obrigar o grupo a reiniciar do começo.

Cada dungeon poderá possuir checkpoints.

Exemplo

Entrada

↓

Checkpoint 1

↓

Mini Boss

↓

Checkpoint 2

↓

Puzzle

↓

Checkpoint 3

↓

Boss Final

---

Ao alcançar um checkpoint:

- monstros anteriores permanecem mortos;
- portas continuam abertas;
- puzzles resolvidos permanecem resolvidos.

---

# Sistema de Wipe

Caso todos os jogadores morram.

A dungeon poderá agir de maneiras diferentes.

Modo 1

Todos retornam ao checkpoint.

---

Modo 2

Boss recupera vida.

---

Modo 3

Boss reinicia completamente.

---

Modo 4

Dungeon falha.

Instância destruída.

---

Cada dungeon poderá escolher seu comportamento.

---

# Sistema de Ressurreição

Existem diversas possibilidades.

### Ressurreição automática

Após alguns segundos.

---

### Ressurreição pelo Curandeiro

Classes específicas.

---

### Altar da Vida

Existem altares espalhados.

---

### Cristais

O grupo possui vidas limitadas.

Exemplo

5 Cristais.

Cada morte.

↓

-1 Cristal.

Quando chegar a zero.

↓

Dungeon encerrada.

---

# Sistema de Puzzles

Nem todo desafio deve ser combate.

Existem puzzles.

---

## Alavancas

Todas devem ser ativadas simultaneamente.

---

## Runas

Jogadores precisam encontrar símbolos.

---

## Espelhos

Refletem feixes de luz.

---

## Estátuas

Precisam ser empurradas.

---

## Labirintos

A parede muda constantemente.

---

## Música

Sequência correta de notas.

---

## Pressão

Jogadores precisam permanecer em determinadas posições.

---

## Cooperação

Cada jogador recebe uma habilidade.

Somente utilizando todas corretamente o puzzle será resolvido.

---

# Sistema de Armadilhas

A dungeon possui armadilhas.

Exemplos

Espinhos.

Lâminas.

Flechas.

Veneno.

Piso quebradiço.

Buracos.

Bolas de pedra.

Fogo.

Gelo.

Correntes elétricas.

As armadilhas podem ser ativadas por monstros ou pelos próprios jogadores.

---

# Sistema de Salas Secretas

Algumas salas não aparecem normalmente.

Exemplos

Parede falsa.

Livro escondido.

Interruptor secreto.

Evento raro.

Chance de aparecer.

Somente determinados eventos.

Essas salas possuem recompensas únicas.

---

# Sistema de Relíquias

Relíquias são recompensas permanentes.

Não são equipamentos.

São artefatos históricos.

Cada jogador possui um inventário de relíquias.

---

Exemplos

Coração do Rei Escarlate

+2% dano contra Vampiros.

---

Olho da Serafina

Enxerga passagens ocultas.

---

Lágrima da Rainha Feérica

+10% cura recebida.

---

Fragmento do Eclipse

Reduz dano de magia sombria.

---

As relíquias incentivam explorar todo o conteúdo do jogo.

---

# Sistema de Baús

Cada boss gera um baú.

O loot pode funcionar de três formas.

---

## Loot Compartilhado

Todos disputam.

---

## Loot Individual

Cada jogador possui seu próprio baú.

Recomendado.

---

## Loot Inteligente

O sistema considera:

Classe.

Especialização.

Equipamentos.

Itens já obtidos.

Necessidade do grupo.

Isso reduz frustração.

---

# Sistema de Moedas

Cada dungeon poderá conceder moedas próprias.

Exemplo

Insígnia Carmesim.

Utilizada para comprar:

Armaduras.

Mascotes.

Montarias.

Cosméticos.

Relíquias.

Assim o progresso não depende apenas da sorte.

---

# Sistema de Conquistas

Cada dungeon possui dezenas de conquistas.

Exemplos

Sem mortes.

↓

Título.

---

Completar em menos de 15 minutos.

↓

Montaria.

---

Derrotar Boss sem destruir cristais.

↓

Cosmético.

---

Encontrar todas as salas secretas.

↓

Pet exclusivo.

---

# Dungeon Journal

O Dungeon Journal registra tudo que o jogador descobriu.

Cada dungeon possui:

- História.
- Mapa.
- Chefes.
- Habilidades dos chefes.
- Estratégias.
- Relíquias.
- Loot.
- Conquistas.
- Personagens importantes.

Informações desconhecidas aparecem ocultas até serem descobertas.

---

# Sistema de Exploração

A exploração deve ser recompensada.

Exemplos

Objetos interativos.

Livros.

Diários.

Cartas.

Murais.

Pinturas.

Runas.

Esses elementos ampliam a lore do mundo e desbloqueiam novas entradas no Journal.

---

# Sistema de Narrativa

Cada dungeon deve contar uma história.

Estrutura recomendada:

Introdução

↓

Exploração

↓

Conflito

↓

Clímax

↓

Conclusão

O jogador deve sair da dungeon entendendo por que aquele lugar existe e qual seu papel na história do mundo.

---

# Princípios de Design

Ao criar uma nova dungeon, siga estas diretrizes:

- Cada chefe deve possuir uma identidade própria.
- Cada sala deve ter uma função narrativa ou mecânica.
- O jogador nunca deve caminhar longas distâncias sem encontrar interação.
- Sempre misture combate, exploração e resolução de desafios.
- Recompense curiosidade com salas secretas, relíquias e histórias ocultas.
- Evite encontros repetitivos; alterne o ritmo entre batalhas intensas e momentos de exploração.
- Faça com que o ambiente participe da experiência, usando iluminação, clima, objetos destrutíveis e eventos dinâmicos.

Uma boa dungeon não é apenas difícil. Ela é memorável e faz o jogador querer retornar para descobrir tudo o que ainda ficou escondido.