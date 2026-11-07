# PollisBenchmarks.jl

The published benchmarks that [Pollis](https://pollis.org) runs on the chat models of a computer: each benchmark downloaded once at a fixed revision of its dataset, a stratified sample of its questions drawn with a seed, each model's answers graded as they come, and the score of each model with its 95% interval.

Pollis's Model Benchmarks page (Compose > Local Models > Model Benchmarks...) runs these functions, and a notebook can call the same ones:

```julia
import PollisBenchmarks as PB
PB.download("gsm8k")
sample = PB.draw("gsm8k"; size = 100, seed = 1)
run = PB.new_run("gsm8k", sample; shots = 0, reasoning = true)
PB.run_models!(run, ["hf:unsloth/Qwen3.5-0.8B-GGUF/Qwen3.5-0.8B-Q4_K_M.gguf"])
PB.figures(run)
```

`run_models!` starts each model's llama-server through Pollis, so it runs in the Julia REPL or a notebook of Pollis. `run_model!` takes the address of a server already running.

## Benchmarks

| Id | Benchmark | Questions | Strata | Grading | Licence | |
|---|---|---|---|---|---|---|
| `mmlu-pro` | MMLU-Pro (Wang et al., 2024) | 12,032 | 14 subjects | The letter of the option, read as its evaluation scripts read it | MIT | Built in |
| `gsm8k` | GSM8K (Cobbe et al., 2021) | 1,319 | None | The final number | MIT | Built in |

`data/catalogue.toml` describes each benchmark: what it measures, its source and the revision its questions come from, its licence, how an answer is graded, and whether it is built in. The questions of a benchmark built in come with the package, in its artifact `benchmarks` (one Parquet file of questions and one of examples each, with `LICENCES.md`), made from its source at that revision; Pollis copies them into its built-in database PollisBenchmarks. Any other benchmark is downloaded from its source the first time it is run, at the same fixed revision. `download(id)` makes the questions ready in `~/.pollis/benchmarks/data/<id>` either way. Each benchmark's questions keep the licence of their source.

## Runs

A run is kept in `~/.pollis/benchmarks/runs`: `<id>.json`, the benchmark and its revision, the settings, the sample and each model's figures; and `<id>.jsonl`, each answer with its grade and timings.

## Licence

MIT, for the code. The questions of each benchmark keep their own licence.
