# FinQA (Chen, Chen, Smiley, Shah, Borova, Langdon, Moussa, Beane, Huang, Routledge and Wang, 2021): questions on a
# page of an annual report, its sentences and its table, answered with a number, or yes or no. The answer is read
# from "the answer is N", or else the last number of the answer. A number is right within 1% of the right one, or of
# the right one times 100, a ratio given as a percentage; yes or no is matched exactly.

"""The page of the report of a question: its sentences before the table, the table a row a line, and its sentences after."""
function finqa_report(question)
	table = join([join(something.(row, ""), " | ") for row in question.report_table], "\n")
	join(something.(question.pre_text, ""), " ") * "\n\n" * table * "\n\n" * join(something.(question.post_text, ""), " ")
end

finqa_question(question) = "Report:\n$(finqa_report(question))\n\nQuestion: $(question.question)\nAnswer:"

function finqa_prompt(question, examples, settings)
	if settings.reasoning
		head = "Answer each question from the page of the annual report given with it. Think step by step and then finish your answer with \"the answer is N\", where N is the number, or yes or no.\n\n"
		shown = join(["$(finqa_question(example)) The computation is $(example.worked). So the answer is $(example.answer).\n\n" for example in examples])
		return head * shown * finqa_question(question)
	end
	head = "Answer each question from the page of the annual report given with it. Give only the answer, as \"the answer is N\", where N is the number, or yes or no.\n\n"
	head * join(["$(finqa_question(example)) The answer is $(example.answer).\n\n" for example in examples]) * finqa_question(question)
end

"""A number as written in an answer, with its sign, its dollar sign and its commas, and a percent sign after it."""
const FINQA_NUMBER = r"-?\$?\s?\d[\d,]*(?:\.\d+)?\s?%?"

function finqa_extract(text)
	said = collect(eachmatch(Regex("(?i)answer is[:\\s]*\\**\\s*(yes|no|" * FINQA_NUMBER.pattern * ")"), text))
	isempty(said) || return lowercase(replace(String(last(said).captures[1]), r"\s" => ""))
	numbers = collect(eachmatch(FINQA_NUMBER, text))
	isempty(numbers) ? nothing : replace(String(last(numbers).match), r"\s" => "")
end

"""Whether `given` is within 1% of `right`; for a right answer of 0, whether it is 0."""
within_one_percent(given, right) = right == 0 ? abs(given) <= 1e-9 : abs(given - right) <= 0.01 * abs(right)

function finqa_grade(extracted, answer)
	right = lowercase(strip(answer))
	right in ("yes", "no") && return lowercase(extracted) == right
	given, value = plain_number(replace(extracted, "%" => "")), plain_number(right)
	given === nothing || value === nothing ? false : within_one_percent(given, value) || within_one_percent(given, 100 * value)
end

register!(Benchmark(
	"finqa", "FinQA", revision_of("finqa"),
	nothing, nothing, nothing, nothing,
	finqa_prompt,
	finqa_extract,
	(extracted, question) -> finqa_grade(extracted, question.answer),
	(examples, question, shots) -> first(examples, shots),
	nothing,
	identity,
))
