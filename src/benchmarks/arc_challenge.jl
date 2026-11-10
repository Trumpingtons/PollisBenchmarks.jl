# ARC-Challenge (Clark et al., 2018): the grade-school science questions of the AI2 Reasoning Challenge that a
# retrieval and a word co-occurrence method both failed on, its test split; three to five options, labelled A to E or
# 1 to 5 in the source, asked here with the letters A to E, as those of MMLU-Pro, without examples.

"""The revision of allenai/ai2_arc on Hugging Face, fixed in the catalogue."""
const ARC_CHALLENGE_REVISION = revision_of("arc_challenge")

"""A question of ARC-Challenge as kept: its options by their letters, the right one by its letter, whatever the labels of the source."""
function arc_challenge_row(row)
	labels = String.(row.choices.label)
	right = findfirst(==(String(row.answerKey)), labels)
	right === nothing && error("ARC-Challenge question $(row.id): its answer $(row.answerKey) is none of its labels $(join(labels, ", ")).")
	(; id = String(row.id), stratum = "", question = String(row.question), choices = String.(row.choices.text),
		answer = string(LETTERS[right]), worked = "")
end

register!(Benchmark(
	"arc_challenge", "ARC-Challenge", ARC_CHALLENGE_REVISION,
	"https://huggingface.co/datasets/allenai/ai2_arc/resolve/$(ARC_CHALLENGE_REVISION)/ARC-Challenge/test-00000-of-00001.parquet",
	nothing,
	nothing,
	(row, index) -> arc_challenge_row(row),
	single_choice_prompt,
	text -> choice_extract(text, 'E'),
	(extracted, question) -> extracted == question.answer,
	(examples, question, shots) -> [],
	question -> 1 / length(question.choices),
	identity,
))
