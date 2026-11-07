"""
The number of questions of each stratum, of populations `populations`, for a sample of `size`: each stratum has one
at least, when the size allows, and the rest is shared in proportion to the populations ("proportional") or equally
("equal"), by largest remainders, a stratum never given more than it has; the shares a stratum cannot take go to the
others. The page of Pollis computes the same (modelBenchmarksPage.ts, allocate).
"""
function allocate(size::Integer, populations::AbstractVector{<:Integer}, allocation::AbstractString)
	count = length(populations)
	sizes = zeros(Int, count)
	left = min(size, sum(populations))
	if left >= count
		sizes .= min.(1, populations)
		left -= sum(sizes)
	end
	while left > 0
		open_strata = findall(sizes .< populations)
		isempty(open_strata) && break
		weights = allocation == "equal" ? ones(length(open_strata)) : Float64.(populations[open_strata])
		quotas = left .* weights ./ sum(weights)
		whole = floor.(Int, quotas)
		# The remainders, largest first, the earlier stratum first on a tie
		order = sortperm(quotas .- whole; rev = true, alg = Base.Sort.DEFAULT_STABLE)
		for index in order[1:(left - sum(whole))]
			whole[index] += 1
		end
		given = min.(whole, populations[open_strata] .- sizes[open_strata])
		sizes[open_strata] .+= given
		left -= sum(given)
		sum(given) == 0 && break
	end
	sizes
end

"""
	draw(benchmark; size, strata = nothing, allocation = "proportional", seed = 1)

A stratified random sample of the questions of `benchmark`: from the strata named in `strata` (all of them when
nothing), `size` questions shared among them by `allocation` ("proportional" or "equal"), drawn within each stratum
with `seed`, the same seed drawing the same sample again. A benchmark without strata gives a simple random sample.
"""
function draw(id; size::Integer, strata = nothing, allocation::AbstractString = "proportional", seed::Integer = 1)
	questions = read_questions(id)
	names = sort(unique(question.stratum for question in questions))
	chosen = strata === nothing || isempty(strata) ? names : filter(in(Set(String.(strata))), names)
	isempty(chosen) && error("None of the strata $(strata) is in $(benchmark_of(id).name).")
	groups = [sort([question.id for question in questions if question.stratum == name]) for name in chosen]
	sizes = allocate(size, length.(groups), allocation)
	rng = Xoshiro(seed)
	ids = String[]
	for (group, count) in zip(groups, sizes)
		append!(ids, shuffle(rng, group)[1:count])
	end
	(; benchmark = benchmark_of(id).id, seed, allocation = String(allocation), size = length(ids),
		strata = [(; name, population = length(group), size = count) for (name, group, count) in zip(chosen, groups, sizes)], ids)
end
