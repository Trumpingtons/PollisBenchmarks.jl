# MMLU-Pro (Wang et al., 2024): ten options, 14 subjects; the prompt and the reading of the answer of its own
# evaluation scripts (TIGER-AI-Lab/MMLU-Pro, evaluate_from_api.py): "the answer is (X)", else "Answer: X", else the
# last letter that stands alone.

const LETTERS = collect("ABCDEFGHIJ")

function mmlu_pro_row(row)
	options = [String(option) for option in row.options if option !== nothing && !isempty(strip(String(option)))]
	(; id = string(row.question_id), stratum = String(row.category), question = String(row.question),
		choices = options, answer = String(row.answer), worked = row.cot_content === nothing ? "" : String(row.cot_content))
end

function mmlu_pro_question(question; with_answer = false)
	text = "Question:\n$(question.question)\nOptions:\n"
	for (letter, option) in zip(LETTERS, question.choices)
		text *= "$(letter). $(option)\n"
	end
	with_answer || return text * "Answer: Let's think step by step."
	text * replace(question.worked, "A: Let's think step by step." => "Answer: Let's think step by step.") * "\n\n"
end

function mmlu_pro_prompt(question, examples, settings)
	if settings.reasoning
		head = "The following are multiple choice questions (with answers) about $(question.stratum). Think step by step and then finish your answer with \"the answer is (X)\" where X is the correct letter choice.\n\n\n"
		return head * join(mmlu_pro_question.(examples; with_answer = true)) * mmlu_pro_question(question)
	end
	head = "The following are multiple choice questions about $(question.stratum). Give only the correct letter choice, as \"the answer is (X)\".\n\n\n"
	shown = join(["$(chop(mmlu_pro_question(example), tail = length("Let's think step by step.")))the answer is ($(example.answer))\n\n" for example in examples])
	head * shown * chop(mmlu_pro_question(question), tail = length(" Let's think step by step."))
end

function mmlu_pro_extract(text)
	found = match(r"answer is \(?([A-J])\)?", text)
	found === nothing || return String(found.captures[1])
	found = match(r"(?s).*[aA]nswer:\s*\(?([A-J])\)?", text)
	found === nothing || return String(found.captures[1])
	found = match(r"(?s)\b([A-J])\b(?!.*\b[A-J]\b)", text)
	found === nothing ? nothing : String(found.captures[1])
end

"""The revision of TIGER-Lab/MMLU-Pro on Hugging Face, fixed so that the questions do not change when the dataset is updated."""
const MMLU_PRO_REVISION = "b189ec765aa7ed75c8acfea42df31fdae71f97be"

register!(Benchmark(
	"mmlu-pro", "MMLU-Pro", MMLU_PRO_REVISION,
	"https://huggingface.co/datasets/TIGER-Lab/MMLU-Pro/resolve/$(MMLU_PRO_REVISION)/data/test-00000-of-00001.parquet",
	"https://huggingface.co/datasets/TIGER-Lab/MMLU-Pro/resolve/$(MMLU_PRO_REVISION)/data/validation-00000-of-00001.parquet",
	"category",
	(row, index) -> mmlu_pro_row(row),
	mmlu_pro_prompt,
	mmlu_pro_extract,
	(extracted, answer) -> extracted == answer,
	(examples, question, shots) -> first(filter(example -> example.stratum == question.stratum, examples), shots),
	question -> 1 / length(question.choices),
))
