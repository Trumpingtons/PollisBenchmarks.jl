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

| Id | Benchmark | What it measures | Questions | Licence | |
|---|---|---|---|---|---|
| `mmlu_pro` | MMLU-Pro | Closed Book Answering | 12,032 | MIT | Built In |
| `gsm8k` | GSM8K | Closed Book Answering | 1,319 | MIT | Built In |
| `truthfulqa` | TruthfulQA | Closed Book Answering | 817 | Apache-2.0 | Built In |
| `bbh` | BIG-Bench Hard | Closed Book Answering | 6,511 | MIT | Built In |
| `ifeval` | IFEval | Instruction Following | 541 | Apache-2.0 | Built In |
| `multipl_e_julia` | MultiPL-E, Julia | Code | 159 | BSD-3-Clause, with a Machine Learning Restriction | Built In |
| `bfcl` | Berkeley Function Calling Leaderboard | Tool Use | 2,501 | Apache-2.0 | Built In |
| `scifact` | SciFact | Embedding, Reranking | 300 queries, 5,183 documents | CC BY 4.0, ODC-By 1.0 | Built In |
| `scidocs` | SCIDOCS | Embedding, Reranking | 1,000 queries, 25,657 documents | CC BY 4.0 | Built In |
| `pubmedqa` | PubMedQA | Open Book Answering | 500 | MIT | Built In |
| `finqa` | FinQA | Open Book Answering | 1,147 | MIT | Built In |
| `arc_challenge` | ARC-Challenge | Closed Book Answering | 1,172 | CC BY-SA 4.0 | Download |
| `gpqa` | GPQA | Closed Book Answering | 448 | CC BY 4.0 | Download |
| `spider` | Spider | Text to SQL | 1,034 | CC BY-SA 4.0 | Download |
| `squad_v2` | SQuAD 2.0 | Open Book Answering | 11,873 | CC BY-SA 4.0 | Download |
| `hotpotqa` | HotpotQA | Open Book Answering | 7,405 | CC BY-SA 4.0 | Download |
| `qasper` | QASPER | Open Book Answering | | CC BY 4.0 | Download |
| `multihop_rag` | MultiHop-RAG | Open Library Answering | 2,556 | ODC-By | Download |
| `nfcorpus` | NFCorpus | Embedding, Reranking | 323 queries, 3,633 documents | Academic use only | Download |
| `fiqa` | FiQA-2018 | Embedding, Reranking | 648 queries, 57,638 documents | Non-commercial use only | Download |
| `trec_covid` | TREC-COVID | Embedding, Reranking | 50 queries, 171,332 documents | Not stated at its source | Download |
| `crag` | CRAG | Open Library Answering | | CC BY-NC 4.0 | Download |
| `financebench` | FinanceBench | Open Library Answering | 150 | CC BY-NC 4.0 | Download |
| `natural_questions` | Natural Questions | Open Library Answering | 7,830 | CC BY-SA 3.0 | Download |

`data/catalogue.toml` describes each benchmark: what it measures, its sources and the revision of each its questions come from, its licence, how an answer is graded, the columns of its own, and whether it is built in. The questions of a benchmark Built In come with the package, in its artifact `benchmarks`: a Parquet file of questions for each, one of examples when it has them and one of documents for a retrieval benchmark, with `LICENCES.md`, made from their sources at those revisions. Pollis copies them into its built-in database PollisBenchmarks, a table for each benchmark. The questions of a benchmark to Download are not in the artifact, by their licence or their size: they are fetched from their source, at its revision, by a page that runs them. The questions of each benchmark keep the licence of their source.

MMLU-Pro and GSM8K run: `download(id)` makes their questions ready in `~/.pollis/benchmarks/data/<id>`, from the artifact, or from their source when the artifact is not on the computer.

## Runs

A run is kept in `~/.pollis/benchmarks/runs`: `<id>.json`, the benchmark and its revision, the settings, the sample and each model's figures; and `<id>.jsonl`, each answer with its grade and timings.

## Licence

MIT, for the code. The questions of each benchmark keep their own licence.
