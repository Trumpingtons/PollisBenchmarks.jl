# GSM8K (Cobbe et al., 2021): the number after "####" in the worked answer is the right one; the model's is the one
# of "The answer is N", else the last number of its text.

"""The number of a text such as "\$1,250.00" or "18.", without its commas, dollar sign and full stop."""
function plain_number(text)
	cleaned = rstrip(replace(String(text), "," => "", "\$" => ""), '.')
	tryparse(Float64, cleaned)
end

function gsm8k_row(row, index)
	worked, answer = split(String(row.answer), "####"; limit = 2)
	(; id = string(index), stratum = "", question = String(row.question), choices = String[],
		answer = strip(answer), worked = strip(replace(worked, r"<<[^>]*>>" => "")))
end

function gsm8k_prompt(question, examples, settings)
	if settings.reasoning
		head = "Solve the following math problems step by step. The last line of your response should be of the form \"The answer is N\", where N is the final number.\n\n"
		shown = join(["Question: $(example.question)\nAnswer: $(example.worked)\nThe answer is $(example.answer).\n\n" for example in examples])
		return head * shown * "Question: $(question.question)\nAnswer:"
	end
	head = "Solve the following math problems. Give only the final number, as \"The answer is N\".\n\n"
	shown = join(["Question: $(example.question)\nAnswer: The answer is $(example.answer).\n\n" for example in examples])
	head * shown * "Question: $(question.question)\nAnswer:"
end

const NUMBER = r"-?\$?\s?\d[\d,]*(?:\.\d+)?"

function gsm8k_extract(text)
	said = collect(eachmatch(Regex("(?i)the (?:final )?answer is[:\\s]*\\**\\s*(" * NUMBER.pattern * ")"), text))
	isempty(said) || return replace(String(last(said).captures[1]), r"\s" => "")
	marked = collect(eachmatch(Regex("####\\s*(" * NUMBER.pattern * ")"), text))
	isempty(marked) || return replace(String(last(marked).captures[1]), r"\s" => "")
	numbers = collect(eachmatch(NUMBER, text))
	isempty(numbers) ? nothing : replace(String(last(numbers).match), r"\s" => "")
end

function gsm8k_grade(extracted, answer)
	given, right = plain_number(extracted), plain_number(answer)
	given !== nothing && right !== nothing && abs(given - right) <= 1e-6 * max(1, abs(right))
end

"""The revision of openai/gsm8k on Hugging Face, fixed in the catalogue so that the questions do not change when the dataset is updated."""
const GSM8K_REVISION = revision_of("gsm8k")

register!(Benchmark(
	"gsm8k", "GSM8K", GSM8K_REVISION,
	"https://huggingface.co/datasets/openai/gsm8k/resolve/$(GSM8K_REVISION)/main/test-00000-of-00001.parquet",
	"https://huggingface.co/datasets/openai/gsm8k/resolve/$(GSM8K_REVISION)/main/train-00000-of-00001.parquet",
	nothing,
	gsm8k_row,
	gsm8k_prompt,
	gsm8k_extract,
	gsm8k_grade,
	(examples, question, shots) -> first(examples, shots),
	nothing,
))
