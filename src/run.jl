"""The longest answer when a run asks for the answer alone, without thinking."""
const ANSWER_ONLY_TOKENS = 32

"""
	new_run(benchmark, sample; shots = 0, reasoning = true, thinking = false, max_tokens = 2048, pollis = "")

A run of `benchmark` on the questions of `sample` (from `draw`): with `shots` examples before each question, the
answer worked step by step or given alone (`reasoning`), the model thinking first or not (`thinking`, for the
models that do), at most `max_tokens` tokens an answer, or `ANSWER_ONLY_TOKENS` for the answer alone without
thinking. Kept in `RUNS`; answers its id.
"""
function new_run(id, sample; shots::Integer = 0, reasoning::Bool = true, thinking::Bool = false, max_tokens::Integer = 2048, pollis::AbstractString = "")
	benchmark = benchmark_of(id).id
	# The answer alone, without thinking: room for the answer and a short sentence, so that an answer worked out
	# against the instruction is cut off at once
	reasoning || thinking || (max_tokens = ANSWER_ONLY_TOKENS)
	run = (; id = string(uuid4()), started = round(Int, time() * 1000), pollis = String(pollis), benchmark,
		revision = downloaded_revision(benchmark),
		settings = (; shots, reasoning, thinking, maxTokens = max_tokens),
		sample = (; sample.seed, sample.allocation, sample.size, sample.strata, questions = sample.ids),
		models = [])
	write_json(run_file(run.id), run)
	touch(answers_file(run.id))
	run.id
end

run_file(id) = joinpath(RUNS, "$(id).json")
answers_file(id) = joinpath(RUNS, "$(id).jsonl")

"""The run `id` as kept."""
load_run(id) = JSON3.read(read(run_file(id), String))

"""The answers of the run `id`, each as written: (; model, id, extracted, correct, ...)."""
function load_answers(id)
	path = answers_file(id)
	isfile(path) || return []
	answers = []
	for line in eachline(path)
		isempty(line) && continue
		try
			push!(answers, JSON3.read(line))
		catch
			# A line cut off when the run was stopped
		end
	end
	answers
end

"""
The memory free on this computer, in bytes, as the Julia extension of Pollis measures it (pollisModels.ts,
availableMemory): on macOS the memory less what the processes hold, as vm_stat counts it, on Linux MemAvailable.
"""
function available_memory()
	if Sys.isapple()
		stats = try read(`vm_stat`, String) catch; "" end
		size = match(r"page size of (\d+) bytes", stats)
		pages(name) = (found = match(Regex("$(name):\\s+(\\d+)"), stats); found === nothing ? nothing : parse(Int, found.captures[1]))
		counts = pages.(["Anonymous pages", "Pages purgeable", "Pages wired down", "Pages occupied by compressor"])
		(size === nothing || any(isnothing, counts)) && return Int(Sys.free_memory())
		used = (counts[1] - counts[2] + counts[3] + counts[4]) * parse(Int, size.captures[1])
		return max(0, Int(Sys.total_memory()) - used)
	elseif Sys.islinux()
		info = try read("/proc/meminfo", String) catch; "" end
		found = match(r"(?m)^MemAvailable:\s+(\d+) kB", info)
		found === nothing || return parse(Int, found.captures[1]) * 1024
	end
	Int(Sys.free_memory())
end

const MODEL_DOWNLOADER = Ref{Union{Nothing, Downloads.Downloader}}(nothing)

"""
The downloader of the requests to a model's server, made the first time: llama-server sends nothing until the answer is
written, which can take minutes, so the 20 seconds without a byte after which Downloads gives up are lifted; the
`timeout` of each answer still holds.
"""
function model_downloader()
	if MODEL_DOWNLOADER[] === nothing
		downloader = Downloads.Downloader()
		downloader.easy_hook = (easy, info) -> Downloads.Curl.setopt(easy, Downloads.Curl.CURLOPT_LOW_SPEED_TIME, 0)
		MODEL_DOWNLOADER[] = downloader
	end
	MODEL_DOWNLOADER[]
end

"""
One answer of the model at `url`, the OpenAI-compatible API of its llama-server: its text, why it ended, its tokens
and its timings, as llama-server measures them; or the error.
"""
function ask(url, prompt; max_tokens, timeout = 900)
	body = JSON3.write((; messages = [(; role = "user", content = prompt)], temperature = 0, max_tokens, stream = false))
	output = IOBuffer()
	started = time()
	response = Downloads.request(rstrip(url, '/') * "/chat/completions"; method = "POST", input = IOBuffer(body), output,
		headers = ["Content-Type" => "application/json"], timeout, throw = false, downloader = model_downloader())
	seconds = time() - started
	response isa Downloads.Response || return (; error = first(sprint(showerror, response), 300), seconds)
	text = String(take!(output))
	response.status == 200 || return (; error = "HTTP $(response.status): $(first(text, 300))", seconds)
	reply = JSON3.read(text)
	choice = first(reply.choices)
	timings = get(reply, :timings, nothing)
	usage = get(reply, :usage, nothing)
	number(object, key) = object === nothing ? nothing : get(object, key, nothing)
	# The milliseconds of a token written, which the first token takes after the question is read
	written, writing_ms = number(timings, :predicted_n), number(timings, :predicted_ms)
	token_ms = written isa Real && writing_ms isa Real && written > 0 ? writing_ms / written : nothing
	(; text = something(get(choice.message, :content, nothing), ""), finish = String(something(get(choice, :finish_reason, nothing), "")),
		seconds, promptTokens = number(usage, :prompt_tokens), writtenTokens = number(usage, :completion_tokens),
		promptMs = number(timings, :prompt_ms), readingSpeed = number(timings, :prompt_per_second),
		writingSpeed = number(timings, :predicted_per_second), tokenMs = token_ms)
end

"""
	run_model!(run, model, url; label = model, size = "", free_before = available_memory(), progress = (done, total, tokens) -> nothing)

Has the model `model` (its file or `hf:` value), whose llama-server is at `url`, answer the questions of the run
`run`, one after the other, each answer written as it comes and graded; the model's figures are kept in the run
after each answer and at the end. The memory it takes is `free_before`, the memory free before its server started,
less the least memory free while it answers.
"""
function run_model!(id, model, url; label = model, size = "", free_before = available_memory(), progress = (done, total, tokens) -> nothing)
	run = load_run(id)
	benchmark = benchmark_of(run.benchmark)
	by_id = Dict(question.id => question for question in read_questions(run.benchmark))
	examples = run.settings.shots > 0 ? read_questions(run.benchmark, "examples.jsonl") : []
	questions = [by_id[String(question)] for question in run.sample.questions]
	settings = (; reasoning = run.settings.reasoning)
	entry = Dict{Symbol, Any}(:value => String(model), :label => String(label), :size => String(size), :started => round(Int, time() * 1000),
		:freeBefore => free_before, :lowestFree => available_memory())
	save_model!(id, entry)
	# The least memory free while the model answers, every two seconds
	watch = Timer(_ -> (entry[:lowestFree] = min(entry[:lowestFree], available_memory())), 0; interval = 2)
	tokens = [0, 0]
	failures = 0
	try
		for (done, question) in enumerate(questions)
			prompt = benchmark.prompt(question, benchmark.examples_of(examples, question, run.settings.shots), settings)
			answer = ask(url, prompt; max_tokens = run.settings.maxTokens)
			if hasproperty(answer, :error)
				failures += 1
				record = (; model = entry[:value], id = question.id, stratum = question.stratum, error = answer.error, answer.seconds)
				entry[:error] = answer.error
			else
				extracted = benchmark.extract(answer.text)
				correct = extracted !== nothing && benchmark.grade(extracted, question.answer)
				tokens .+= (something(answer.promptTokens, 0), something(answer.writtenTokens, 0))
				record = (; model = entry[:value], id = question.id, stratum = question.stratum, extracted, correct, answer.text, answer.finish,
					answer.seconds, answer.promptTokens, answer.writtenTokens, answer.promptMs, answer.readingSpeed, answer.writingSpeed, answer.tokenMs)
			end
			open(io -> (JSON3.write(io, record); println(io)), answers_file(id), "a")
			# The figures kept after each answer, before it is reported, so that the page shows the run as it goes
			save_model!(id, entry)
			progress(done, length(questions), tokens)
			# A server that stopped answering: the questions left are not asked
			failures >= 3 && failures == done && break
		end
	finally
		close(watch)
		entry[:lowestFree] = min(entry[:lowestFree], available_memory())
		entry[:ended] = round(Int, time() * 1000)
		save_model!(id, entry)
	end
	figures(id)
end

"""Keeps `entry`, the model's line of the run, in place of the one of the same model, and the figures of all the models."""
function save_model!(id, entry)
	run = Dict{Symbol, Any}(pairs(load_run(id)))
	models = [Dict{Symbol, Any}(pairs(model)) for model in run[:models] if String(model.value) != entry[:value]]
	push!(models, copy(entry))
	run[:models] = models
	run[:figures] = figures(id; run = run)
	write_json(run_file(id), run)
end

"""
	run_models!(run, models; progress = (model, done, total, tokens) -> nothing)

Runs each model of `models` (files or `hf:` values) on the run `run`, one after the other and each alone in
memory: its llama-server started for it (`Pollis.llama_server`, in the Julia REPL or a notebook of Pollis) and
stopped once it has answered. The run is then marked ended (`ended`), so that Pollis moves it into its Comparisons.duckdb.
"""
function run_models!(id, models; progress = (model, done, total, tokens) -> nothing)
	pollis = isdefined(Main, :Pollis) ? Main.Pollis : error("run_models! runs in the Julia REPL or a notebook of Pollis.")
	thinking = Bool(load_run(id).settings.thinking)
	for model in models
		free_before = available_memory()
		url = pollis.llama_server(model; thinking)
		try
			run_model!(id, model, url; label = replace(basename(String(model)), r"\.gguf$"i => ""), free_before, progress = (done, total, tokens) -> progress(model, done, total, tokens))
		finally
			pollis.stop_llama_server(model; thinking)
		end
	end
	end_run!(id)
	figures(id)
end

"""Marks the run `id` ended, when it was."""
function end_run!(id)
	run = Dict{Symbol, Any}(pairs(load_run(id)))
	run[:ended] = round(Int, time() * 1000)
	write_json(run_file(id), run)
end

"""The runs kept, the latest first: their ids."""
function runs()
	isdir(RUNS) || return String[]
	files = [file for file in readdir(RUNS) if endswith(file, ".json")]
	ids = [file[1:end - 5] for file in files]
	sort(ids; by = id -> load_run(id).started, rev = true)
end
