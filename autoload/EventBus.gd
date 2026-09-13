extends Node
## Global signal bus. Add signals here as features need to communicate
## across scenes without direct references.

## Emitted by the scorer ([code]#26[/code]) whenever the scoring state
## changes: which edges have contact, where each floater sits along its edge,
## and how many share it. The music system ([code]#33[/code], [code]#34[/code])
## is the consumer. Neither side is meant to reference the other directly —
## this signal and the [ScoringSnapshot] it carries are the whole contract
## between them. See [ScoringSnapshot] for the shape of the data and the
## publish-cadence decision behind it.
signal scoring_updated(snapshot: ScoringSnapshot)
