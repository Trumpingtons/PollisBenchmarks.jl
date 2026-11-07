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

"""The catalogue of the benchmarks, `data/catalogue.toml`: what each measures, its sources and revisions, its licence and whether it is built in."""
const CATALOGUE_FILE = joinpath(dirname(@__DIR__), "data", "catalogue.toml")
include_dependency(CATALOGUE_FILE)
const CATALOGUE = Dict(entry["id"] => entry for entry in TOML.parsefile(CATALOGUE_FILE)["benchmarks"])

"""
	catalogue()

The entries of the catalogue, one per benchmark: id, benchmark, component, domain, layout, availability (Built In,
its questions in the artifact, or Download, fetched from its source), questions, documents (for a benchmark that
searches documents), released, licence, licence_url, source and revision (each source and its revision, in the same
order), grading, page (the page of Pollis that runs it, when there is one), reference and, for one built in, table
(the name of its table in Pollis's database PollisBenchmarks) and columns.
"""
catalogue() = [CATALOGUE[id] for id in sort(collect(keys(CATALOGUE)))]

"""The entry of the catalogue of the benchmark `id`."""
catalogue_entry(id) = get(CATALOGUE, String(id)) do
	error("No benchmark $(id) in the catalogue of PollisBenchmarks.")
end

"""The revision of the first source of the benchmark `id`, the one its questions come from."""
revision_of(id) = String(first(catalogue_entry(id)["revision"]))

"""Whether the questions of the benchmark `id` come with the package, in its artifact, rather than from its source."""
built_in(id) = catalogue_entry(id)["availability"] == "Built In"

"""The Artifacts.toml of the package, which names the artifact `benchmarks`, the questions of the benchmarks."""
const ARTIFACTS_FILE = joinpath(dirname(@__DIR__), "Artifacts.toml")

"""
The folder of the artifact `benchmarks`, which Pkg downloads with the package: `<id>.parquet`, the questions of each
benchmark built in, with `<id>-examples.parquet`, its examples, and `<id>-documents.parquet`, the documents of a retrieval
benchmark, when it has them; and `LICENCES.md`. Nothing when the artifact is not on this computer.
"""
function artifact_folder()
	isfile(ARTIFACTS_FILE) || return nothing
	hash = artifact_hash("benchmarks", ARTIFACTS_FILE)
	hash === nothing && return nothing
	folder = artifact_path(hash)
	isdir(folder) ? folder : nothing
end
