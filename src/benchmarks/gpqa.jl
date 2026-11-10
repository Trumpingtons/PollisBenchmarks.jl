# GPQA (Rein et al., 2024): the 448 questions of its main set, in biology, physics and chemistry, written and checked
# by experts; one right answer and three wrong ones each, in the columns of the source. Its files on Hugging Face are
# given only to an account that has accepted its terms, so the download needs a token of that account. The right
# answer is put at a place fixed by the question's id, as TruthfulQA's true option, and the question asked and read as
# those of MMLU-Pro, without examples.

"""The revision of Idavidrein/gpqa on Hugging Face, fixed in the catalogue."""
const GPQA_REVISION = revision_of("gpqa")

"""A question of GPQA as kept, from a row of its CSV file: the right answer first, then the three wrong ones; its stratum the domain."""
function gpqa_row(row, index)
	text(column) = String(strip(something(get(row, Symbol(column), nothing), "")))
	id = text("Record ID")
	(; id = isempty(id) ? string(index) : id, stratum = text("High-level domain"), question = text("Question"),
		choices = [text("Correct Answer"), text("Incorrect Answer 1"), text("Incorrect Answer 2"), text("Incorrect Answer 3")],
		answer = "A", worked = "")
end

register!(Benchmark(
	"gpqa", "GPQA", GPQA_REVISION,
	"https://huggingface.co/datasets/Idavidrein/gpqa/resolve/$(GPQA_REVISION)/gpqa_main.csv",
	nothing,
	"High-level domain",
	gpqa_row,
	single_choice_prompt,
	text -> choice_extract(text, 'D'),
	(extracted, question) -> extracted == question.answer,
	(examples, question, shots) -> [],
	question -> 1 / length(question.choices),
	place_true_option,
))
