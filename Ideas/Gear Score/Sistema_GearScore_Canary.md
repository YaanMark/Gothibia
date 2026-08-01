# Sistema de Gear Score para Canary

## Objetivo

Implementar um sistema moderno de **Item Level (iLv)** e **Gear Score (GS)** no Canary.

## Conceitos

- **Item Level (iLv):** qualidade base do equipamento.
- **Gear Score (GS):** poder efetivo do item após modificadores.

Fórmula sugerida:

```text
GS = (iLv × Multiplicador da Raridade)
     + Bônus de Refino
     + Bônus de Encantamentos
```

O GS do personagem é a soma do GS de todos os equipamentos.

## Raridades

|Raridade|Multiplicador|
|---|---:|
|Comum|1.00|
|Incomum|1.15|
|Raro|1.35|
|Épico|1.60|
|Lendário|2.00|
|Relíquia|2.50|

## Exemplo

Espada:
- iLv: 150
- Épica (1.6)
- Refino +8 = +40 GS
- Encantamentos = +20 GS

```text
GS = (150 × 1.6) + 40 + 20 = 300
```

---

# Arquitetura

## Item

Adicionar propriedades:

```cpp
uint16_t itemLevel;
uint16_t gearScoreBase;
uint8_t rarity;
uint8_t refineLevel;
std::vector<Enchant> enchants;
```

## Player

Adicionar:

```cpp
uint32_t gearScore;
void recalculateGearScore();
uint32_t getGearScore() const;
```

Sempre recalcular ao equipar, desequipar ou alterar um item.

---

# API Lua

```lua
player:getGearScore()
player:recalculateGearScore()

item:getItemLevel()
item:getRarity()
item:getRefineLevel()
item:getGearScore()
```

---

# Integrações

## Dungeons

```lua
if player:getGearScore() < 900 then
    player:sendTextMessage(MESSAGE_FAILURE,
        "Gear Score insuficiente.")
    return false
end
```

## Bosses

Exibir GS recomendado antes da luta.

## NPCs

Permitir diálogos condicionados ao GS.

---

# Escalonamento

Calcular média do GS do grupo.

```text
GS Médio = soma / jogadores
```

Exemplo:

- Dungeon recomendada: 1000
- Grupo: 1400

Aplicar:

- +25% HP
- +15% dano
- +5% chance de loot raro

---

# OTClient

Enviar GS no login e sempre que mudar.

Exibir:

```text
Gear Score
1325
Rank: Herói
```

---

# Persistência

Preferencialmente derivar o GS dos itens equipados.
Persistir apenas atributos individuais dos itens (iLv, raridade, refino, encantamentos).

---

# Roadmap

## Fase 1
- Item Level
- Gear Score
- Recalcular ao equipar

## Fase 2
- Raridades

## Fase 3
- Refino

## Fase 4
- Encantamentos

## Fase 5
- UI do cliente

## Fase 6
- Dungeons, NPCs, Bosses

## Boas práticas

- Nunca salvar GS final do jogador no banco.
- Recalcular sempre.
- Expor API Lua.
- Manter sistema modular.
- Evitar alterar lógica de combate; usar GS apenas para progressão e acesso a conteúdo.
