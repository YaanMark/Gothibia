RefinementConfig = {
    -- Níveis de qualidade e seu refino máximo
    MaxRefine = {
        [0] = 5, -- Comum
        [1] = 6, -- Incomum
        [2] = 8, -- Raro
        [3] = 10, -- Épico
        [4] = 10, -- Lendário
        [5] = 10, -- Relíquia
    },
    
    -- Configurações para cada nível
    Levels = {
        [1] = { chance = 100, gold = 1000, materials = {{id = 3040, count = 1}} }, -- 3040 = gold nugget
        [2] = { chance = 100, gold = 2000, materials = {{id = 3040, count = 2}} },
        [3] = { chance = 90, gold = 5000, materials = {{id = 3040, count = 3}} },
        [4] = { chance = 80, gold = 10000, materials = {{id = 3040, count = 4}} },
        [5] = { chance = 70, gold = 20000, materials = {{id = 3040, count = 5}} },
        [6] = { chance = 60, gold = 50000, materials = {{id = 3040, count = 6}} },
        [7] = { chance = 45, gold = 100000, materials = {{id = 3040, count = 7}} },
        [8] = { chance = 30, gold = 200000, materials = {{id = 3040, count = 8}} },
        [9] = { chance = 20, gold = 500000, materials = {{id = 3040, count = 9}} },
        [10] = { chance = 10, gold = 1000000, materials = {{id = 3040, count = 10}} },
    }
}
