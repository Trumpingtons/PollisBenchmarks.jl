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

| Id | Benchmark | Questions | Strata | Grading |
|---|---|---|---|---|
| `mmlu-pro` | MMLU-Pro (Wang et al., 2024) | 12,032 | 14 subjects | The letter of the option, read as its evaluation scripts read it |
| `gsm8k` | GSM8K (Cobbe et al., 2021) | 1,319 | None | The final number |

Each benchmark is downloaded from Hugging Face into `~/.pollis/benchmarks/data/<id>`, at the revision fixed in its file under `src/benchmarks`, so that a later download gives the same questions. Its questions keep the licence of their source.

## Runs

A run is kept in `~/.pollis/benchmarks/runs`: `<id>.json`, the benchmark and its revision, the settings, the sample and each model's figures; and `<id>.jsonl`, each answer with its grade and timings.

## Licence

MIT, for the code. The questions of each benchmark keep their own licence.
