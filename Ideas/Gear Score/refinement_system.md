# Sistema de Refino para OTServer Canary

## Objetivo

O Sistema de Refino aumenta a progressão dos equipamentos através de
materiais, ouro e pedras especiais, integrando-se ao Gear Score e ao
sistema de Dungeons.

## Objetivos

-   Criar Gold Sink.
-   Criar Material Sink.
-   Valorizar Bosses e Dungeons.
-   Aumentar o Gear Score.
-   Permitir progressão de longo prazo.

## Funcionamento

Cada equipamento possui um nível de refino (`+0` até `+10`).

Exemplo:

``` text
Knight Sword
Refino: +5
```

## Limites por Qualidade

  Qualidade   Máximo
  ----------- --------
  Comum       +5
  Incomum     +6
  Raro        +8
  Épico       +10
  Lendário    +10
  Relíquia    +10

## Bônus por Refino

  Refino   Bônus
  -------- -------
  +1       +2%
  +2       +4%
  +3       +6%
  +4       +8%
  +5       +10%
  +6       +13%
  +7       +16%
  +8       +20%
  +9       +25%
  +10      +30%

Os bônus são aplicados em ataque, defesa, armor e Gear Score.

## Chances

  Refino   Chance
  -------- --------
  0→1      100%
  1→2      100%
  2→3      90%
  3→4      80%
  4→5      70%
  5→6      60%
  6→7      45%
  7→8      30%
  8→9      20%
  9→10     10%

Toda configuração deve ficar em:

``` text
data/lib/refinement/refine_config.lua
```

Exemplo:

``` lua
RefinementConfig = {
    [1] = {
        chance = 100,
        gold = 5000,
        materials = {
            {id = 1001, count = 1}
        }
    }
}
```

## Materiais

Exemplos: - Pedra de Refino - Pedra Avançada - Pedra Lendária - Iron
Ore - Crystal Dust - Dragon Heart - Ancient Crystal

Obtidos em: - Dungeons - Bosses - Eventos - Crafting

## Ouro

O custo aumenta progressivamente conforme o nível de refino.

## Falha

-   Até +3: nenhuma penalidade.
-   +4 até +6: perde 1 nível.
-   +7 até +10: perde 2 níveis.

Nunca destrói o equipamento.

## Pedra de Proteção

Impede perda de nível durante uma falha e é consumida.

## Pedra Perfeita

Garante 100% de sucesso e é extremamente rara.

## Persistência

Adicionar um atributo persistente ao Item:

``` cpp
ITEM_ATTRIBUTE_REFINE
```

Caso não exista, criar um novo atributo no enum de atributos do Canary.

Também reservar atributos para: - Afinidade - Awakening

## Alterações no Core

Arquivos sugeridos:

``` text
src/item.h
src/item.cpp
src/items.h
src/items.cpp
src/luascript.h
src/luascript.cpp
src/iomapserialize.cpp
```

Adicionar métodos:

``` cpp
uint8_t Item::getRefine() const;
void Item::setRefine(uint8_t level);
void Item::addRefine();
```

Lua:

``` lua
item:getRefine()
item:setRefine(level)
item:addRefine()
item:getMaxRefine()
```

## Biblioteca Lua

Criar:

``` text
data/lib/refinement/refinement.lua
```

Responsável por: - validar materiais - validar ouro - calcular chance -
aplicar sucesso/falha - atualizar atributos - atualizar Gear Score

## NPC Ferreiro

Criar:

``` text
data/scripts/npcs/blacksmith.lua
```

Fluxo:

1.  Seleciona item.
2.  Verifica limite.
3.  Verifica ouro.
4.  Verifica materiais.
5.  Calcula chance.
6.  Sucesso ou falha.
7.  Atualiza atributos.

## Atualização dos Atributos

Após alterar o refino:

``` lua
updateRefinementStats(item)
```

Recalcular: - ataque - defesa - armor - Gear Score

## Integração com Loot

Bosses e Dungeons devem fornecer pedras e materiais de refino.

## Estrutura Recomendada

``` text
data/
 ├── lib/
 │   └── refinement/
 │       ├── refine_config.lua
 │       └── refinement.lua
 └── scripts/
     ├── npcs/
     │   └── blacksmith.lua
     └── actions/
         └── refinement_stone.lua
```

## Checklist

-   [ ] Criar atributo ITEM_ATTRIBUTE_REFINE
-   [ ] Salvar/carregar atributo
-   [ ] Criar API Lua
-   [ ] Criar refine_config.lua
-   [ ] Criar refinement.lua
-   [ ] Criar NPC
-   [ ] Consumir ouro
-   [ ] Consumir materiais
-   [ ] Calcular chance
-   [ ] Atualizar atributos
-   [ ] Atualizar Gear Score
-   [ ] Atualizar descrição dos itens

## Expansões Futuras

-   Awakening
-   Afinidade
-   Transferência de Refino
-   Encantamentos
-   Bônus aleatórios
