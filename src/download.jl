"""The rows that DuckDB reads with `reader`, such as `read_parquet('file')`, as JSON objects."""
function read_rows(reader)
	json = tempname() * ".jsonl"
	try
		db = DuckDB.DB()
		try
			DBInterface.execute(db, "COPY (SELECT * FROM $(reader)) TO '$(replace(json, "'" => "''"))' (FORMAT JSON)")
		finally
			DBInterface.close!(db)
		end
		[JSON3.read(line) for line in eachline(json) if !isempty(line)]
	finally
		rm(json; force = true)
	end
end

"""The rows of a Parquet file, read with DuckDB, as JSON objects."""
parquet_rows(file) = read_rows("read_parquet('$(replace(file, "'" => "''"))')")

"""The rows of a Parquet file, or of a CSV file with a header, its every column read as text."""
table_rows(file) = endswith(lowercase(file), ".csv") ?
	read_rows("read_csv('$(replace(file, "'" => "''"))', header = true, all_varchar = true)") : parquet_rows(file)

"""
The token of Hugging Face that Pollis gives the processes it starts, set in Pollis or by the user: the environment
variable HUGGING_FACE_HUB_TOKEN, or else HF_TOKEN; nothing when neither is set.
"""
function hugging_face_token()
	for name in ("HUGGING_FACE_HUB_TOKEN", "HF_TOKEN")
		token = strip(get(ENV, name, ""))
		isempty(token) || return String(token)
	end
	nothing
end

"""
The file `url` downloaded to `path`, unless it is there already; a file of Hugging Face with the token of
`hugging_face_token`, when there is one, which a dataset that asks its users to accept its terms needs.
"""
function fetch_file(url, path)
	isfile(path) && return path
	mkpath(dirname(path))
	partial = path * ".part"
	token = hugging_face_token()
	headers = token !== nothing && startswith(url, "https://huggingface.co/") ? ["Authorization" => "Bearer $(token)"] : Pair{String, String}[]
	try
		Downloads.download(url, partial; headers)
	catch
		rm(partial; force = true)
		rethrow()
	end
	mv(partial, path; force = true)
end

"""Whether `error` is the refusal of a server to give a file without the right to it: 401 or 403."""
refused(error) = error isa Downloads.RequestError && error.response.status in (401, 403)

"""The extension of the file of `url`, such as ".parquet" or ".csv"."""
extension_of(url) = lowercase(splitext(first(split(url, '?')))[2])

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
	local questions_file, examples_file
	try
		questions_file = fetch_file(benchmark.questions, joinpath(folder, "questions" * extension_of(benchmark.questions)))
		progress(1, 3)
		# A benchmark without examples has no file of them
		examples_file = benchmark.examples === nothing ? nothing : fetch_file(benchmark.examples, joinpath(folder, "examples" * extension_of(benchmark.examples)))
	catch err
		refused(err) || rethrow()
		source = first(catalogue_entry(benchmark.id)["source"])
		error(hugging_face_token() === nothing ?
			"$(benchmark.name) asks its users to accept its terms on Hugging Face: accept them at $(source) while signed in, then set your Hugging Face token (Set token, on the Powered by line of Benchmark Answering Models, or the environment variable HUGGING_FACE_HUB_TOKEN)." :
			"Hugging Face refused the files of $(benchmark.name) with the token given: accept its terms at $(source) while signed in with the account of the token, or check the token.")
	end
	progress(2, 3)
	read(file) = [benchmark.arrange(benchmark.read_row(row, index)) for (index, row) in enumerate(table_rows(file))]
	(; questions = read(questions_file), examples = examples_file === nothing ? [] : read(examples_file))
end

"""
	download(benchmark; progress = (done, total) -> nothing)

Makes the questions and examples of `benchmark` (an id of `BENCHMARKS`, such as "mmlu_pro") ready in `DATA/<benchmark>`, at the revision
of the dataset that the catalogue fixes, and answers its `info`: the revision and the number of questions of each
stratum. The questions of a benchmark built in are read from the artifact of the package; those of any other, or
when the artifact is not on this computer, are downloaded from their source, once, and again when its files are of
another revision.
"""
function download(id; progress = (done, total) -> nothing)
	benchmark = benchmark_of(id)
	folder = joinpath(DATA, benchmark.id)
	artifact = built_in(benchmark.id) ? artifact_folder() : nothing
	if artifact !== nothing
		progress(0, 3)
		questions = [benchmark.arrange(question_of(row)) for row in parquet_rows(joinpath(artifact, "$(benchmark.id).parquet"))]
		# A benchmark without examples has no file of them
		examples_file = joinpath(artifact, "$(benchmark.id)-examples.parquet")
		examples = isfile(examples_file) ? [benchmark.arrange(question_of(row)) for row in parquet_rows(examples_file)] : []
	elseif benchmark.questions === nothing
		error("The questions of $(benchmark.name) come with PollisBenchmarks.jl, in its artifact benchmarks, which is not on this computer: install the package again.")
	else
		if downloaded_revision(benchmark.id) != benchmark.revision
			for name in ("questions", "examples"), extension in (".parquet", ".csv")
				rm(joinpath(folder, name * extension); force = true)
			end
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

"""The columns every benchmark has."""
const COMMON_COLUMNS = (:id, :stratum, :question, :choices, :answer, :worked)

"""
A question as kept: its id, stratum, question, choices, right answer and worked answer; then the columns of its
benchmark's own, as they are, such as the abstract of a question of PubMedQA (`context`, `sections`), the instructions
of one of IFEval or the unit tests of one of MultiPL-E Julia.
"""
function question_of(object)
	common = (; id = String(object.id), stratum = String(object.stratum), question = String(object.question),
		choices = String.(object.choices), answer = String(object.answer), worked = String(object.worked))
	own = (; (key => value for (key, value) in pairs(object) if !(Symbol(key) in COMMON_COLUMNS))...)
	merge(common, own)
end

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
