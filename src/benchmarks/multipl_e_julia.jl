# MultiPL-E, Julia (Cassano, Gouwar, Nguyen, Nguyen, Phipps-Costin, Pinckney, Yee, Zi, Anderson, Feldman, Guha,
# Greenberg and Jangda, 2023): the HumanEval problems in Julia, the docstring and the signature of a function to
# complete. The model is asked for the whole function in a code block; the function is run with its unit tests, in a
# Julia process of its own, in an empty folder, stopped after `TEST_SECONDS`, and is right when they all pass (pass@1).
# The process is not a sandbox: the code the model wrote can reach the files and the network of this computer.

"""The seconds the unit tests of an answer may take, as MultiPL-E's own harness allows."""
const TEST_SECONDS = 15

function multipl_e_prompt(question, examples, settings)
	task = "Complete the following Julia function."
	ask = settings.reasoning ? "Think it through, then give the whole function, from its docstring to its end, in one ```julia code block." :
		"Give only the whole function, from its docstring to its end, in one ```julia code block, without explanation."
	"$(task) $(ask)\n\n```julia\n$(question.question)```"
end

"""The code of the answer: its first ```julia code block, or else its first code block, or else the answer itself when it defines a function."""
function multipl_e_extract(text)
	for block in (r"```(?:julia|jl)[^\n]*\n(.*?)```"is, r"```[^\n]*\n(.*?)```"s)
		found = match(block, text)
		found === nothing || return String(found.captures[1])
	end
	occursin(r"\bfunction\b", text) ? String(text) : nothing
end

"""The program run: the function, completed from the prompt when the answer gives only its body, then the unit tests."""
function multipl_e_program(code, question)
	name = last(collect(eachmatch(r"function\s+(\w+)", question.question))).captures[1]
	whole = occursin(Regex("function\\s+$(name)\\b"), code) ? code : question.question * code
	whole * "\n\n" * question.tests
end

"""
Whether `program` runs to its end without an error within `seconds`: in a Julia process of its own, without startup
file and with the standard library only, in an empty temporary folder, removed after.
"""
function runs_without_error(program; seconds = TEST_SECONDS)
	mktempdir() do folder
		file = joinpath(folder, "program.jl")
		write(file, program)
		command = Cmd(`$(Base.julia_cmd()) --startup-file=no --history-file=no $(file)`; dir = folder)
		environment = filter(entry -> !(first(entry) in ("JULIA_PROJECT", "JULIA_LOAD_PATH")), ENV)
		command = setenv(command, merge(environment, Dict("JULIA_LOAD_PATH" => "@stdlib")))
		process = run(pipeline(command; stdout = devnull, stderr = devnull); wait = false)
		timer = Timer(_ -> process_running(process) && kill(process), seconds)
		try
			wait(process)
		finally
			close(timer)
		end
		success(process)
	end
end

register!(Benchmark(
	"multipl_e_julia", "MultiPL-E, Julia", revision_of("multipl_e_julia"),
	nothing, nothing, nothing, nothing,
	multipl_e_prompt,
	multipl_e_extract,
	(code, question) -> runs_without_error(multipl_e_program(code, question)),
	(examples, question, shots) -> [],
	nothing,
	identity,
))
