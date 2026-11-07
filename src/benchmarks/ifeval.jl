# IFEval (Zhou, Lu, Mishra, Brahma, Basu, Luan, Zhou and Hou, 2023): prompts with instructions that can be checked,
# such as a number of words, a format or a word not to use. The prompt is asked as it is; the answer is right when it
# follows every instruction of its prompt (prompt-level strict accuracy). Each instruction is checked by the rule of
# the checker of IFEval's authors (google-research/instruction_following_eval, instructions.py and evaluation_lib.py),
# with three differences, for what that checker leaves to Python libraries: sentences are counted by the splitter of
# the same checker (instructions_util.split_into_sentences) rather than by the one of NLTK; the words of
# capital_word_frequency are runs of letters and digits joined by hyphens rather than the words of NLTK; and the
# language of an answer is found by the trigrams of Languages.jl among the languages of the checker, a language
# Languages.jl has no trigrams of (Swahili) counting as followed, as the checker counts an answer whose language it
# cannot find. A letter_frequency instruction whose letter is not one from a to z counts that character.

import Languages

"""A comparison of IFEval: "less than" or "at least" `threshold`."""
ifeval_compare(number, relation, threshold) = relation == "less than" ? number < threshold : number >= threshold

"""Whether the text has a letter and all its letters are capitals (Python's isupper), or all lower case (islower)."""
all_upper(text) = (letters = filter(character -> isuppercase(character) || islowercase(character), text); !isempty(letters) && all(isuppercase, letters))
all_lower(text) = (letters = filter(character -> isuppercase(character) || islowercase(character), text); !isempty(letters) && all(islowercase, letters))

"""The languages of IFEval's checker, by their ISO 639-1 code, as Languages.jl names those it has trigrams of."""
const IFEVAL_LANGUAGES = Dict(
	"en" => "eng", "es" => "spa", "pt" => "por", "ar" => "arb", "hi" => "hin", "fr" => "fra", "ru" => "rus", "de" => "deu",
	"ja" => "jpn", "it" => "ita", "bn" => "ben", "uk" => "ukr", "th" => "tha", "ur" => "urd", "ta" => "tam", "te" => "tel",
	"bg" => "bul", "ko" => "kor", "pl" => "pol", "he" => "heb", "fa" => "pes", "vi" => "vie", "ne" => "nep", "kn" => "kan",
	"mr" => "mar", "gu" => "guj", "pa" => "pan", "ml" => "mal", "fi" => "fin")

"""The language of a script that only one language of the checker is written in."""
const SCRIPT_LANGUAGES = Dict(Languages.BengaliScript => "bn", Languages.HangulScript => "ko", Languages.KannadaScript => "kn",
	Languages.TamilScript => "ta", Languages.ThaiScript => "th", Languages.GujaratiScript => "gu", Languages.GurmukhiScript => "pa",
	Languages.TeluguScript => "te", Languages.MalayalamScript => "ml", Languages.HiraganaScript => "ja", Languages.KatakanaScript => "ja")

"""
The language of `text`, by its ISO 639-1 code: by its script, or, for a script several languages are written in, the
language of the checker whose trigrams in Languages.jl are nearest those of the text; nothing when it cannot be found.
"""
function text_language(text)
	isempty(strip(text)) && return nothing
	script = Languages.detect_script(text)
	script isa Tuple && (script = first(script))
	script === nothing && return nothing
	models = get(Languages.trigram_models, Languages.name(script), nothing)
	models === nothing && return get(SCRIPT_LANGUAGES, typeof(script), nothing)
	trigrams = Languages.get_trigrams_with_positions(String(text))
	distances = [(code, Languages.calculate_distance(models[model], trigrams)) for (code, model) in IFEVAL_LANGUAGES if haskey(models, model)]
	isempty(distances) ? nothing : first(argmin(last, distances))
end

"""Whether `text` is in the language `code`; an answer whose language cannot be found, or in a language without trigrams, counts as in it."""
function in_language(text, code)
	haskey(IFEVAL_LANGUAGES, code) || return true
	found = text_language(text)
	found === nothing || found == code
end

"""The sentences of `text`, as instructions_util.split_into_sentences of the checker splits them."""
function split_into_sentences(text)
	alphabets, digits = "([A-Za-z])", "([0-9])"
	prefixes, suffixes = "(Mr|St|Mrs|Ms|Dr)[.]", "(Inc|Ltd|Jr|Sr|Co)"
	starters = raw"(Mr|Mrs|Ms|Dr|Prof|Capt|Cpt|Lt|He\s|She\s|It\s|They\s|Their\s|Our\s|We\s|But\s|However\s|That\s|This\s|Wherever)"
	acronyms, websites = "([A-Z][.][A-Z][.](?:[A-Z][.])?)", "[.](com|net|org|io|gov|edu|me)"
	text = replace(" " * text * "  ", "\n" => " ")
	text = replace(text, Regex(prefixes) => s"\1<prd>")
	text = replace(text, Regex(websites) => s"<prd>\1")
	text = replace(text, Regex(digits * "[.]" * digits) => s"\1<prd>\2")
	text = replace(text, r"\.{2,}" => dots -> "<prd>"^length(dots) * "<stop>")
	text = replace(text, "Ph.D." => "Ph<prd>D<prd>")
	text = replace(text, Regex("\\s" * alphabets * "[.] ") => s" \1<prd> ")
	text = replace(text, Regex(acronyms * " " * starters) => s"\1<stop> \2")
	text = replace(text, Regex(alphabets * "[.]" * alphabets * "[.]" * alphabets * "[.]") => s"\1<prd>\2<prd>\3<prd>")
	text = replace(text, Regex(alphabets * "[.]" * alphabets * "[.]") => s"\1<prd>\2<prd>")
	text = replace(text, Regex(" " * suffixes * "[.] " * starters) => s" \1<stop> \2")
	text = replace(text, Regex(" " * suffixes * "[.]") => s" \1<prd>")
	text = replace(text, Regex(" " * alphabets * "[.]") => s" \1<prd>")
	text = replace(text, ".”" => "”.", ".\"" => "\".", "!\"" => "\"!", "?\"" => "\"?")
	text = replace(text, "." => ".<stop>", "?" => "?<stop>", "!" => "!<stop>")
	text = replace(text, "<prd>" => ".")
	sentences = strip.(split(text, "<stop>"))
	!isempty(sentences) && isempty(last(sentences)) && pop!(sentences)
	sentences
end

"""Whether the paragraphs of `text` split by `separator` are `wanted`, with an empty one only at the start or the end."""
function paragraph_count_is(text, separator, wanted)
	paragraphs = split(text, separator)
	number = length(paragraphs)
	for (index, paragraph) in enumerate(paragraphs)
		if isempty(strip(paragraph))
			(index == 1 || index == length(paragraphs)) || return false
			number -= 1
		end
	end
	number == wanted
end

"""Whether the `nth` of the paragraphs of `text`, split by empty lines, starts with `first_word`, and they are `wanted`."""
function nth_paragraph_starts_with(text, wanted, nth, first_word)
	paragraphs = split(text, "\n\n")
	number = length(paragraphs) - count(paragraph -> isempty(strip(paragraph)), paragraphs)
	nth <= number || return false
	paragraph = strip(paragraphs[nth])
	isempty(paragraph) && return false
	word = lstrip(lstrip(first(split(paragraph)), '\''), '"')
	found = lowercase(String(collect(Iterators.takewhile(letter -> !(letter in ".,?!'\""), word))))
	number == wanted && found == lowercase(first_word)
end

"""The highlighted sections of `text`: *text* and **text**, as the checker counts them."""
function highlighted_sections(text)
	single = count(found -> !isempty(strip(strip(found.match, '*'))), eachmatch(r"\*[^\n\*]*\*", text))
	double = count(found -> !isempty(strip(chopsuffix(chopprefix(found.match, "**"), "**"))), eachmatch(r"\*\*[^\n\*]*\*\*", text))
	single + double
end

"""Whether `text` is JSON, once a code fence around it is taken away."""
function is_json(text)
	value = strip(text)
	for prefix in ("```json", "```Json", "```JSON", "```")
		value = chopprefix(value, prefix)
	end
	value = strip(chopsuffix(value, "```"))
	try
		JSON3.read(value)
		true
	catch
		false
	end
end

"""A regular expression the checker builds from `pattern`, ignoring case, or the pattern taken as text when it is not one."""
function search_pattern(pattern)
	try
		Regex(pattern, "i")
	catch
		Regex(replace(pattern, r"([\\^$.|?*+()\[\]{}])" => s"\\\1"), "i")
	end
end

"""Whether `text` follows the instruction `instruction` with its arguments `arguments`, by the rule of IFEval's checker."""
function follows(text, instruction, arguments)
	argument(key) = get(arguments, key, nothing)
	if instruction == "keywords:existence"
		all(keyword -> occursin(search_pattern(String(keyword)), text), argument(:keywords))
	elseif instruction == "keywords:frequency"
		ifeval_compare(length(collect(eachmatch(search_pattern(strip(String(argument(:keyword)))), text))), argument(:relation), argument(:frequency))
	elseif instruction == "keywords:forbidden_words"
		!any(word -> occursin(search_pattern("\\b" * String(word) * "\\b"), text), argument(:forbidden_words))
	elseif instruction == "keywords:letter_frequency"
		letter = only(lowercase(strip(String(argument(:letter)))))
		ifeval_compare(count(==(letter), lowercase(text)), argument(:let_relation), argument(:let_frequency))
	elseif instruction == "language:response_language"
		in_language(text, String(argument(:language)))
	elseif instruction == "length_constraints:number_sentences"
		ifeval_compare(length(split_into_sentences(text)), argument(:relation), argument(:num_sentences))
	elseif instruction == "length_constraints:number_paragraphs"
		paragraph_count_is(text, r"\s?\*\*\*\s?", argument(:num_paragraphs))
	elseif instruction == "length_constraints:number_words"
		ifeval_compare(length(collect(eachmatch(r"\w+", text))), argument(:relation), argument(:num_words))
	elseif instruction == "length_constraints:nth_paragraph_first_word"
		nth_paragraph_starts_with(text, argument(:num_paragraphs), argument(:nth_paragraph), String(argument(:first_word)))
	elseif instruction == "detectable_content:number_placeholders"
		length(collect(eachmatch(r"\[.*?\]", text))) >= argument(:num_placeholders)
	elseif instruction == "detectable_content:postscript"
		marker = strip(String(argument(:postscript_marker)))
		pattern = marker == "P.P.S" ? r"\s*p\.\s?p\.\s?s.*$"m : marker == "P.S." ? r"\s*p\.\s?s\..*$"m :
			Regex("\\s*" * lowercase(marker) * ".*\$", "m")
		occursin(pattern, lowercase(text))
	elseif instruction == "detectable_format:number_bullet_lists"
		length(collect(eachmatch(r"^\s*\*[^\*].*$"m, text))) + length(collect(eachmatch(r"^\s*-.*$"m, text))) == argument(:num_bullets)
	elseif instruction == "detectable_format:constrained_response"
		any(option -> occursin(option, strip(text)), ("My answer is yes.", "My answer is no.", "My answer is maybe."))
	elseif instruction == "detectable_format:number_highlighted_sections"
		highlighted_sections(text) >= argument(:num_highlights)
	elseif instruction == "detectable_format:multiple_sections"
		splitter = strip(String(argument(:section_spliter)))
		length(split(text, Regex("\\s?" * splitter * "\\s?\\d+\\s?"))) - 1 >= argument(:num_sections)
	elseif instruction == "detectable_format:json_format"
		is_json(text)
	elseif instruction == "detectable_format:title"
		any(found -> !isempty(strip(rstrip(lstrip(found.match, '<'), '>'))), eachmatch(r"<<[^\n]+>>", text))
	elseif instruction == "combination:two_responses"
		responses = split(text, "******")
		kept = String[]
		for (index, response) in enumerate(responses)
			if isempty(strip(response))
				(index == 1 || index == length(responses)) || return false
			else
				push!(kept, response)
			end
		end
		length(kept) == 2 && strip(kept[1]) != strip(kept[2])
	elseif instruction == "combination:repeat_prompt"
		startswith(lowercase(strip(text)), lowercase(strip(String(argument(:prompt_to_repeat)))))
	elseif instruction == "startend:end_checker"
		endswith(lowercase(strip(strip(text), '"')), lowercase(strip(String(argument(:end_phrase)))))
	elseif instruction == "startend:quotation"
		value = strip(text)
		length(value) > 1 && first(value) == '"' && last(value) == '"'
	elseif instruction == "change_case:capital_word_frequency"
		capitals = count(found -> all_upper(found.match), eachmatch(r"\w+(?:-\w+)*", text))
		ifeval_compare(capitals, argument(:capital_relation), argument(:capital_frequency))
	elseif instruction == "change_case:english_capital"
		all_upper(text) && in_language(text, "en")
	elseif instruction == "change_case:english_lowercase"
		all_lower(text) && in_language(text, "en")
	elseif instruction == "punctuation:no_comma"
		!occursin(',', text)
	else
		error("IFEval has no instruction $(instruction).")
	end
end

"""Whether the answer follows every instruction of its prompt: an empty answer follows none."""
function ifeval_grade(text, question)
	isempty(strip(text)) && return false
	arguments = JSON3.read(question.arguments)
	all(follows(text, String(instruction), arguments[index]) for (index, instruction) in enumerate(question.instructions))
end

register!(Benchmark(
	"ifeval", "IFEval", revision_of("ifeval"),
	nothing, nothing, nothing, nothing,
	(question, examples, settings) -> question.question,
	text -> isempty(strip(text)) ? nothing : String(text),
	ifeval_grade,
	(examples, question, shots) -> [],
	nothing,
	identity,
))
