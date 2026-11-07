mean(values) = isempty(values) ? nothing : sum(values) / length(values)

function median(values)
	isempty(values) && return nothing
	sorted = sort(values)
	middle = length(sorted) ÷ 2
	isodd(length(sorted)) ? sorted[middle + 1] : (sorted[middle] + sorted[middle + 1]) / 2
end

"""
The score of a stratified sample, with the half-width of its 95% interval (Cochran, 1977, chapter 5): each stratum's
share of right answers weighted by its share of the population of the strata, its variance the sum of the strata's
W² (1 - n/N) p (1 - p) / (n - 1). A stratum of one question has no variance that can be measured: then there is
no interval.
"""
function stratified_score(strata, right, asked)
	population = sum(stratum.population for stratum in strata)
	score = 0.0
	variance = 0.0
	weight_asked = 0.0
	measured = true
	for stratum in strata
		n = get(asked, stratum.name, 0)
		n == 0 && continue
		weight = stratum.population / population
		p = get(right, stratum.name, 0) / n
		score += weight * p
		weight_asked += weight
		if n > 1
			variance += weight^2 * (1 - n / stratum.population) * p * (1 - p) / (n - 1)
		else
			measured = false
		end
	end
	weight_asked == 0 && return (; score = nothing, half = nothing)
	# Strata not asked yet, while a run goes on: the score of those asked
	(; score = score / weight_asked, half = measured ? 1.96 * sqrt(variance) / weight_asked : nothing)
end

"""
The probability that answers picked at random get at least `right` of the questions right, the answer to each
question right with its own probability of `chances`: the upper tail of the Poisson binomial distribution (Hong, 2013),
computed exactly by adding the questions one at a time.
"""
function chance_of_at_least(right, chances)
	# distribution[k + 1]: the probability of k right answers among the questions added so far
	distribution = [1.0]
	for chance in chances
		next = zeros(length(distribution) + 1)
		next[1:end - 1] .+= (1 - chance) .* distribution
		next[2:end] .+= chance .* distribution
		distribution = next
	end
	right <= 0 ? 1.0 : min(1.0, sum(distribution[right + 1:end]; init = 0.0))
end

"""The chance of a random answer to each question of a benchmark, by question id, read once; nothing for a benchmark without options."""
const CHANCES = Dict{String, Dict{String, Float64}}()
function chances_of(id)
	benchmark = benchmark_of(id)
	benchmark.chance === nothing && return nothing
	get!(() -> Dict(question.id => Float64(benchmark.chance(question)) for question in read_questions(benchmark.id)), CHANCES, benchmark.id)
end

"""
	figures(run)

The figures of each model of the run `run`: its score with the half-width of its 95% interval, its score in each
stratum, the questions answered, the probability that answers picked at random would get as many right or more
(`byChance`, nothing for a benchmark without options), those whose answer could not be read and those cut off at
the most tokens, the time to its first token, how fast it read and wrote, the seconds an answer took and the memory it took.
"""
function figures(id; run = load_run(id))
	answers = load_answers(id)
	strata = run[:sample][:strata]
	chances = chances_of(run[:benchmark])
	map(run[:models]) do model
		mine = [answer for answer in answers if String(answer.model) == String(model[:value])]
		answered = [answer for answer in mine if !haskey(answer, :error)]
		right = Dict{String, Int}()
		asked = Dict{String, Int}()
		for answer in answered
			stratum = String(answer.stratum)
			asked[stratum] = get(asked, stratum, 0) + 1
			answer.correct && (right[stratum] = get(right, stratum, 0) + 1)
		end
		overall = stratified_score(strata, right, asked)
		total = sum(values(right); init = 0)
		# Answers that could not be read count as wrong, as in the score
		by_chance = chances === nothing || isempty(answered) ? nothing : chance_of_at_least(total, [chances[String(answer.id)] for answer in answered])
		numbers(key) = [Float64(answer[key]) for answer in answered if get(answer, key, nothing) isa Real]
		first_token = [Float64(answer.promptMs) + something(get(answer, :tokenMs, nothing), 0.0) for answer in answered if get(answer, :promptMs, nothing) isa Real]
		lowest = get(model, :lowestFree, nothing)
		before = get(model, :freeBefore, nothing)
		(; value = String(model[:value]), label = String(model[:label]), questions = length(answered), failed = length(mine) - length(answered),
			score = overall.score, half = overall.half, right = total, byChance = by_chance,
			strata = [(; name = stratum.name, asked = get(asked, String(stratum.name), 0), right = get(right, String(stratum.name), 0)) for stratum in strata],
			unread = count(answer -> answer.extracted === nothing, answered),
			cutOff = count(answer -> get(answer, :finish, "") == "length", answered),
			firstTokenMs = median(first_token), readingSpeed = median(numbers(:readingSpeed)), writingSpeed = median(numbers(:writingSpeed)),
			seconds = mean(numbers(:seconds)), writtenTokens = mean(numbers(:writtenTokens)),
			memory = before isa Real && lowest isa Real ? max(0, before - lowest) : nothing,
			error = get(model, :error, nothing))
	end
end
