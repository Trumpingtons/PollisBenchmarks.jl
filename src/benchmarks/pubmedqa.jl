# PubMedQA (Jin, Dhingra, Liu, Cohen and Lu, 2019), its 500 test questions of the expert-labelled set, the other 500
# the examples: each answered yes, no or maybe from the abstract of its article without its conclusion, as the source
# asks it. The answer is read from "the answer is X", or else from the first word of the answer.

"""The abstract of the question, a paragraph per section, each headed by its section."""
function pubmedqa_context(question)
	length(question.sections) == length(question.context) || return join(question.context, "\n")
	join(["$(section): $(paragraph)" for (section, paragraph) in zip(question.sections, question.context)], "\n")
end

pubmedqa_question(question) = "Context:\n$(pubmedqa_context(question))\nQuestion: $(question.question)\nAnswer:"

function pubmedqa_prompt(question, examples, settings)
	if settings.reasoning
		head = "Answer each question on medical research from the abstract given with it, with yes, no or maybe. Think step by step and then finish your answer with \"the answer is X\", where X is yes, no or maybe.\n\n"
		shown = join(["$(pubmedqa_question(example)) $(example.worked) So the answer is $(example.answer).\n\n" for example in examples])
		return head * shown * pubmedqa_question(question)
	end
	head = "Answer each question on medical research from the abstract given with it. Give only the answer, as \"the answer is X\", where X is yes, no or maybe.\n\n"
	head * join(["$(pubmedqa_question(example)) The answer is $(example.answer).\n\n" for example in examples]) * pubmedqa_question(question)
end

function pubmedqa_extract(text)
	said = collect(eachmatch(r"(?i)answer is[:\s]*\**\s*\(?(yes|no|maybe)\b", text))
	isempty(said) || return lowercase(String(last(said).captures[1]))
	first_word = match(r"^\W*(yes|no|maybe)\b"i, text)
	first_word === nothing ? nothing : lowercase(String(first_word.captures[1]))
end

register!(Benchmark(
	"pubmedqa", "PubMedQA", revision_of("pubmedqa"),
	nothing, nothing, nothing, nothing,
	pubmedqa_prompt,
	pubmedqa_extract,
	(extracted, question) -> extracted == question.answer,
	(examples, question, shots) -> first(examples, shots),
	question -> 1 / length(question.choices),
	identity,
))
