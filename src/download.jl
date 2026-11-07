"""The rows of a Parquet file, read with DuckDB, as JSON objects."""
function parquet_rows(file)
	json = tempname() * ".jsonl"
	try
		db = DuckDB.DB()
		try
			path = replace(file, "'" => "''")
			DBInterface.execute(db, "COPY (SELECT * FROM read_parquet('$(path)')) TO '$(replace(json, "'" => "''"))' (FORMAT JSON)")
		finally
			DBInterface.close!(db)
		end
		[JSON3.read(line) for line in eachline(json) if !isempty(line)]
	finally
		rm(json; force = true)
	end
end

"""The file `url` downloaded to `path`, unless it is there already."""
function fetch_file(url, path)
	isfile(path) && return path
	mkpath(dirname(path))
	partial = path * ".part"
	Downloads.download(url, partial)
	mv(partial, path; force = true)
end

"""The revision of the dataset that the questions of `benchmark` on this computer come from, or "" when unknown."""
function downloaded_revision(id)
	path = joinpath(DATA, String(id), "info.json")
	isfile(path) || return ""
	String(get(JSON3.read(read(path, String)), :revision, ""))
end

"""
	source_questions(benchmark, folder; progress = (done, total) -> nothing)

The questions and examples of `benchmark` from its source, at the revision of the catalogue: its Parquet files
downloaded into `folder`, unless they are there already, and each row read as kept, (; id, stratum, question,
choices, answer, worked).
"""
function source_questions(id, folder; progress = (done, total) -> nothing)
	benchmark = benchmark_of(id)
	progress(0, 3)
	questions_file = fetch_file(benchmark.questions, joinpath(folder, "questions.parquet"))
	progress(1, 3)
	examples_file = fetch_file(benchmark.examples, joinpath(folder, "examples.parquet"))
	progress(2, 3)
	questions = [benchmark.read_row(row, index) for (index, row) in enumerate(parquet_rows(questions_file))]
	examples = [benchmark.read_row(row, index) for (index, row) in enumerate(parquet_rows(examples_file))]
	(; questions, examples)
end

"""
	download(benchmark; progress = (done, total) -> nothing)

Makes the questions and examples of `benchmark` ("mmlu-pro", "gsm8k") ready in `DATA/<benchmark>`, at the revision
of the dataset that the catalogue fixes, and answers its `info`: the revision and the number of questions of each
stratum. The questions are read from the artifact of the package or, when it is not on this computer, downloaded
from their source, once, and again when its files are of another revision.
"""
function download(id; progress = (done, total) -> nothing)
	benchmark = benchmark_of(id)
	folder = joinpath(DATA, benchmark.id)
	artifact = artifact_folder()
	if artifact !== nothing
		progress(0, 3)
		questions = [question_of(row) for row in parquet_rows(joinpath(artifact, "$(benchmark.id).parquet"))]
		examples = [question_of(row) for row in parquet_rows(joinpath(artifact, "$(benchmark.id)-examples.parquet"))]
	else
		if downloaded_revision(benchmark.id) != benchmark.revision
			rm(joinpath(folder, "questions.parquet"); force = true)
			rm(joinpath(folder, "examples.parquet"); force = true)
		end
		(; questions, examples) = source_questions(benchmark.id, folder; progress)
	end
	write_lines(joinpath(folder, "questions.jsonl"), questions)
	write_lines(joinpath(folder, "examples.jsonl"), examples)
	counts = Dict{String, Int}()
	for question in questions
		counts[question.stratum] = get(counts, question.stratum, 0) + 1
	end
	info = (; benchmark = benchmark.id, revision = benchmark.revision, downloaded = string(now(UTC)), count = length(questions),
		strata = [(; name, count = counts[name]) for name in sort(collect(keys(counts)))])
	write_json(joinpath(folder, "info.json"), info)
	progress(3, 3)
	info
end

"""The questions of a benchmark downloaded, as kept in `questions.jsonl` (or `examples.jsonl`)."""
function read_questions(id, file = "questions.jsonl")
	path = joinpath(DATA, benchmark_of(id).id, file)
	isfile(path) || error("$(benchmark_of(id).name) is not downloaded yet: download(\"$(id)\") first.")
	[question_of(JSON3.read(line)) for line in eachline(path) if !isempty(line)]
end

question_of(object) = (; id = String(object.id), stratum = String(object.stratum), question = String(object.question),
	choices = String.(object.choices), answer = String(object.answer), worked = String(object.worked))

function write_lines(path, values)
	mkpath(dirname(path))
	open(path * ".part", "w") do io
		for value in values
			JSON3.write(io, value)
			println(io)
		end
	end
	mv(path * ".part", path; force = true)
end

function write_json(path, value)
	mkpath(dirname(path))
	write(path * ".part", JSON3.write(value))
	mv(path * ".part", path; force = true)
end
