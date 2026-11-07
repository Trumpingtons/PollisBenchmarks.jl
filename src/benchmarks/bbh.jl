# BIG-Bench Hard (Suzgun, Scales, Schärli, Gehrmann, Tay, Chung, Chowdhery, Le, Chi, Zhou and Wei, 2023): 27 tasks,
# each with the three worked examples of its prompt in the source, "Q: ... A: Let's think step by step. ... So the
# answer is X."; the answer is the text after the last "the answer is", matched exactly, without regard to case. An
# option, such as (B), is matched by its letter, with its brackets or alone.

function bbh_question(question; with_answer = false)
	text = "Q: $(question.question)\nA:"
	with_answer || return text
	text * " $(question.worked)\n\n"
end

function bbh_prompt(question, examples, settings)
	if settings.reasoning
		head = "Answer the following questions. Think step by step, then finish your answer with \"So the answer is X.\", where X is the answer in the form the question asks for.\n\n"
		return head * join(bbh_question.(examples; with_answer = true)) * bbh_question(question) * " Let's think step by step."
	end
	head = "Answer the following questions. Give only the answer, in the form the question asks for, as \"So the answer is X.\"\n\n"
	head * join(["$(bbh_question(example)) So the answer is $(example.answer).\n\n" for example in examples]) * bbh_question(question)
end

function bbh_extract(text)
	said = collect(eachmatch(r"(?i)answer is[:\s]*([^\n]+)", text))
	isempty(said) && return nothing
	# Without the full stop that ends the sentence, and the marks of bold or quoted text
	answer = strip(String(last(said).captures[1]), ['*', '`', '"', ' ', '.'])
	isempty(answer) ? nothing : String(answer)
end

function bbh_grade(extracted, answer)
	given, right = lowercase(strip(extracted)), lowercase(strip(answer))
	given == right && return true
	option = match(r"^\(([a-r])\)$", right)
	option === nothing && return false
	# The option's letter in brackets, followed by its text or not, or the letter alone
	found = something(match(r"^\(([a-r])\)", given), match(r"^([a-r])$", given), Some(nothing))
	found !== nothing && found.captures[1] == option.captures[1]
end

register!(Benchmark(
	"bbh", "BIG-Bench Hard", revision_of("bbh"),
	nothing, nothing, "task", nothing,
	bbh_prompt,
	bbh_extract,
	(extracted, question) -> bbh_grade(extracted, question.answer),
	(examples, question, shots) -> first(filter(example -> example.stratum == question.stratum, examples), shots),
	nothing,
	identity,
))
