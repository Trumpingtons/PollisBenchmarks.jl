# PollisBenchmarks.jl

The published benchmarks of [Pollis](https://pollis.org), with their questions at a fixed revision of their sources, and the functions that run them on the chat models of a computer: a stratified sample of the questions drawn with a seed, each model's answers graded as they come, and the score of each model with its 95% interval.

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

| Id | Benchmark | What it measures | Questions | Licence |
|---|---|---|---|---|
| `mmlu-pro` | MMLU-Pro | Closed Book Answering | 12,032 | MIT |
| `gsm8k` | GSM8K | Closed Book Answering | 1,319 | MIT |
| `truthfulqa` | TruthfulQA | Closed Book Answering | 817 | Apache-2.0 |
| `bbh` | BIG-Bench Hard | Closed Book Answering | 6,511 | MIT |
| `ifeval` | IFEval | Instruction Following | 541 | Apache-2.0 |
| `multipl-e-julia` | MultiPL-E, Julia | Code | 159 | BSD-3-Clause, with a Machine Learning Restriction |
| `bfcl` | Berkeley Function Calling Leaderboard | Tool Use | 2,501 | Apache-2.0 |
| `scifact` | SciFact | Embedding, Reranking | 300 queries, 5,183 documents | CC BY 4.0, ODC-By 1.0 |
| `scidocs` | SCIDOCS | Embedding, Reranking | 1,000 queries, 25,657 documents | CC BY 4.0 |
| `pubmedqa` | PubMedQA | Open Book Answering | 500 | MIT |
| `finqa` | FinQA | Open Book Answering | 1,147 | MIT |

`data/catalogue.toml` describes each benchmark: what it measures, its sources and the revision of each its questions come from, its licence, how an answer is graded, and the columns of its own. The questions come with the package, in its artifact `benchmarks`: a Parquet file of questions for each benchmark, one of examples when it has them and one of documents for a retrieval benchmark, with `LICENCES.md`, made from their sources at those revisions. Pollis copies them into its built-in database PollisBenchmarks, a table for each benchmark. The questions of each benchmark keep the licence of their source.

MMLU-Pro and GSM8K run: `download(id)` makes their questions ready in `~/.pollis/benchmarks/data/<id>`, from the artifact, or from their source when the artifact is not on the computer.

## Runs

A run is kept in `~/.pollis/benchmarks/runs`: `<id>.json`, the benchmark and its revision, the settings, the sample and each model's figures; and `<id>.jsonl`, each answer with its grade and timings.

## Licence

MIT, for the code. The questions of each benchmark keep their own licence.
