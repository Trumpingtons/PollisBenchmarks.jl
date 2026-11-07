"""
A benchmark: where its questions and examples come from, as Parquet files, how a question is written for the model,
and how its answer is read and graded. `strata` names the column the questions are grouped by, or nothing.
"""
struct Benchmark
	id::String
	name::String
	"""The revision of the dataset on Hugging Face its files are downloaded from, so that a later download gives the same questions."""
	revision::String
	questions::String
	examples::String
	strata::Union{Nothing, String}
	"""The question of a row of the Parquet file, as kept: (; id, stratum, question, choices, answer, worked)."""
	read_row::Function
	"""The prompt for a question: the instruction, the examples, then the question."""
	prompt::Function
	"""The answer the model gave, read from its text, or nothing when none can be read."""
	extract::Function
	"""Whether the answer read is the right one."""
	grade::Function
	"""The examples a prompt shows: those of the question's stratum, the first `shots`."""
	examples_of::Function
	"""The probability that an answer picked at random among the question's options is right, or nothing for a benchmark without options."""
	chance::Union{Nothing, Function}
end

"""The benchmarks, by their id, each added by the file that defines it (`benchmarks/`)."""
const BENCHMARKS = Dict{String, Benchmark}()

"""Adds `benchmark` to `BENCHMARKS`."""
register!(benchmark::Benchmark) = (BENCHMARKS[benchmark.id] = benchmark)

"""The benchmark of id `id`."""
benchmark_of(id) = get(BENCHMARKS, String(id)) do
	error("No benchmark $(id): PollisBenchmarks has $(join(sort(collect(keys(BENCHMARKS))), ", ")).")
end
