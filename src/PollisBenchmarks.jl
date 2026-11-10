"""
	PollisBenchmarks

The published benchmarks that Pollis runs on the chat models of a computer, as Benchmark Answering Models does (Compose >
Local AI Models > Benchmark Answering Models... in Pollis). The page runs these functions in a hidden Julia process, and a
notebook calls the same ones, so that both do the same things:

```julia
import PollisBenchmarks as PB
PB.download("mmlu_pro")
sample = PB.draw("mmlu_pro"; size = 140, allocation = "equal", seed = 1)
run = PB.new_run("mmlu_pro", sample; shots = 0, reasoning = true)
PB.run_models!(run, ["hf:unsloth/Qwen3.5-0.8B-GGUF/Qwen3.5-0.8B-Q4_K_M.gguf"])
PB.figures(run)
```

A benchmark is downloaded once into `DATA/<benchmark>`, at a fixed revision of its dataset: its questions,
`questions.jsonl`, one question a line with its id, its stratum, the question, its choices and its right answer; its
examples, `examples.jsonl`, the questions with worked answers that a prompt with examples shows first; and
`info.json`, the revision and the number of questions of each stratum. A sample is drawn from the strata chosen, by
proportional or equal allocation, with a seed, so that it can be drawn again. A run is kept in `RUNS`: `<id>.json`,
the benchmark and its revision, the settings, the sample and the figures of each model, written as the model answers,
and `<id>.jsonl`, each answer as it comes, with its grade and its timings. A run ended, which `run_models!` marks,
Pollis moves into its Comparisons.duckdb.
"""
module PollisBenchmarks

import DBInterface
import Downloads
import DuckDB
import TOML
using Artifacts: artifact_hash, artifact_path
using Dates: now, UTC
using JSON3
using Random: Xoshiro, shuffle
using UUIDs: uuid4

"""Where Pollis keeps the benchmarks' questions and the runs."""
const HOME = joinpath(homedir(), ".pollis", "benchmarks")
const DATA = joinpath(HOME, "data")
const RUNS = joinpath(HOME, "runs")

include("catalogue.jl")
include("benchmarks/mmlu_pro.jl")
include("benchmarks/gsm8k.jl")
include("benchmarks/truthfulqa.jl")
include("benchmarks/bbh.jl")
include("benchmarks/pubmedqa.jl")
include("benchmarks/finqa.jl")
include("benchmarks/ifeval.jl")
include("benchmarks/multipl_e_julia.jl")
include("benchmarks/arc_challenge.jl")
include("benchmarks/gpqa.jl")
include("download.jl")
include("sample.jl")
include("run.jl")
include("figures.jl")

end
