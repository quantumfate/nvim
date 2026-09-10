--- Forwarder so the check is `:checkhealth refactor` rather than
--- `:checkhealth features.refactor`. The engine itself lives in lua/features/refactor/.
return require("features.refactor.health")
