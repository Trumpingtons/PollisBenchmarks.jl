using PollisBenchmarks
using Test

const PB = PollisBenchmarks

# The expected values are worked out by hand from the rules the docstrings state, not from the code.

@testset "PollisBenchmarks" begin
	@testset "MMLU-Pro answers" begin
		@test [PB.mmlu_pro_extract(text) for text in [
			"So the speed doubles. The answer is (C).",
			"Working through it...\nAnswer: B",
			"Option D is the only one that fits",
			"None of these can be right.",
		]] == ["C", "B", "D", nothing]
	end

	@testset "GSM8K answers" begin
		@test [PB.gsm8k_extract(text) for text in [
			"She pays 3 x 4 = 12 dollars.\nThe answer is \$1,250.",
			"First 16 - 3 = 13, then 13 - 4 = 9.\n#### 9",
			"He has 5 apples, then 7.",
			"No numbers here.",
		]] == ["\$1,250", "9", "7", nothing]
		@test [PB.gsm8k_grade(given, right) for (given, right) in [("\$1,250", "1250"), ("18.", "18"), ("17", "18"), ("0.5", ".5")]] ==
			[true, true, false, true]
		row = (; question = "How many eggs?", answer = "She has 16 - 3 = <<16-3=13>>13 eggs.\n#### 13")
		@test PB.gsm8k_row(row, 7) == (; id = "7", stratum = "", question = "How many eggs?", choices = String[], answer = "13", worked = "She has 16 - 3 = 13 eggs.")
	end

	@testset "ARC-Challenge questions" begin
		# Labels 1 to 4 in the source, answer 3: the third option, C
		row = (; id = "Q1", question = "Which is a gas?", choices = (; text = ["rock", "water", "air", "wood"], label = ["1", "2", "3", "4"]), answerKey = "3")
		@test PB.arc_challenge_row(row) == (; id = "Q1", stratum = "", question = "Which is a gas?", choices = ["rock", "water", "air", "wood"], answer = "C", worked = "")
		# Five options: a letter up to E is read
		@test [PB.BENCHMARKS["arc_challenge"].extract(text) for text in ["the answer is (E)", "Answer: B", "none"]] == ["E", "B", nothing]
	end

	@testset "GPQA questions" begin
		row = (; Question = " Which? ", var"Correct Answer" = "right", var"Incorrect Answer 1" = "w1", var"Incorrect Answer 2" = "w2",
			var"Incorrect Answer 3" = "w3", var"Record ID" = "recAAA111", var"High-level domain" = "Physics")
		# The codeunits of "recAAA111" add up to 656: the right answer goes 1 + mod(655, 4) = 4th, letter D
		@test PB.place_true_option(PB.gpqa_row(row, 1)) == (; id = "recAAA111", stratum = "Physics", question = "Which?",
			choices = ["w1", "w2", "w3", "right"], answer = "D", worked = "")
		# Without a record id, the row's number: 2 goes 1 + mod(1, 4) = 2nd, letter B
		@test PB.place_true_option(PB.gpqa_row((; row..., var"Record ID" = nothing), 2)).answer == "B"
		# Four options: E is not a letter of GPQA
		@test [PB.BENCHMARKS["gpqa"].extract(text) for text in ["the answer is (D)", "the answer is (E)"]] == ["D", nothing]
	end

	@testset "Allocation of a sample" begin
		# One each, then 7 left shared equally: 2⅓ each, the extra one to the first stratum
		@test PB.allocate(10, [5, 5, 5], "equal") == [4, 3, 3]
		# One each, then 3 left in proportion to 10, 20 and 2: quotas 0.94, 1.88 and 0.19, the two largest remainders rounded up
		@test PB.allocate(6, [10, 20, 2], "proportional") == [2, 3, 1]
		# A stratum of one question takes no more: what it cannot take goes to the other
		@test PB.allocate(5, [1, 10], "equal") == [1, 4]
		# More asked than there are questions: all of them
		@test PB.allocate(50, [3, 4], "proportional") == [3, 4]
	end

	@testset "Stratified score" begin
		strata = [(; name = "a", population = 100), (; name = "b", population = 300)]
		result = PB.stratified_score(strata, Dict("a" => 5, "b" => 8), Dict("a" => 10, "b" => 10))
		# Score 0.25 × 0.5 + 0.75 × 0.8; variance 0.0625 × 0.9 × 0.25 / 9 + 0.5625 × (29/30) × 0.16 / 9
		@test result.score ≈ 0.725
		@test result.half ≈ 1.96 * sqrt(0.0015625 + 0.5625 * (29 / 30) * 0.16 / 9)
		# A stratum asked once has no variance that can be measured
		@test PB.stratified_score(strata, Dict("a" => 1), Dict("a" => 1, "b" => 10)).half === nothing
	end

	@testset "By chance" begin
		# Two questions of chance one half: at least one right 3/4, both right 1/4
		@test PB.chance_of_at_least(1, [0.5, 0.5]) ≈ 0.75
		@test PB.chance_of_at_least(2, [0.5, 0.5]) ≈ 0.25
		@test PB.chance_of_at_least(0, [0.5, 0.5]) == 1.0
		# Three questions of four options, all right: (1/4)³
		@test PB.chance_of_at_least(3, fill(0.25, 3)) ≈ 1 / 64
	end

	@testset "Catalogue" begin
		@test sort(collect(keys(PB.BENCHMARKS))) == ["arc_challenge", "bbh", "finqa", "gpqa", "gsm8k", "ifeval", "mmlu_pro", "multipl_e_julia", "pubmedqa", "truthfulqa"]
		@test_throws ErrorException PB.benchmark_of("no-such-benchmark")
		# Every benchmark that runs has its entry, of the same revision
		@test all(PB.revision_of(id) == benchmark.revision for (id, benchmark) in PB.BENCHMARKS)
		# The ten benchmarks built in, with their layout, thirteen to download, and as many revisions as sources
		@test [(entry["id"], entry["layout"]) for entry in PB.catalogue() if entry["availability"] == "Built In"] == [
			("bbh", "questions"), ("finqa", "questions"), ("gsm8k", "questions"), ("ifeval", "questions"),
			("mmlu_pro", "questions"), ("multipl_e_julia", "questions"), ("pubmedqa", "questions"), ("scidocs", "retrieval"),
			("scifact", "retrieval"), ("truthfulqa", "questions")]
		# Every id is a name SQL takes without quotes, the name of the table of a benchmark built in
		@test all(entry -> occursin(r"^[a-z][a-z0-9_]*$", entry["id"]), PB.catalogue())
		@test sort([entry["id"] for entry in PB.catalogue() if entry["availability"] == "Download"]) == ["arc_challenge", "crag",
			"financebench", "fiqa", "gpqa", "hotpotqa", "multihop_rag", "natural_questions", "nfcorpus", "qasper", "spider", "squad_v2", "trec_covid"]
		@test all(length(entry["source"]) == length(entry["revision"]) for entry in PB.catalogue())
	end

	@testset "Artifact" begin
		folder = PB.artifact_folder()
		@test folder !== nothing
		rows(file) = isfile(joinpath(folder, file)) ? length(PB.parquet_rows(joinpath(folder, file))) : 0
		# As many questions, examples and documents as their papers and sources give: the test splits of FinQA (1,147)
		# and of PubMedQA (500), the 300 claims of SciFact with relevance labels
		@test [(id, rows("$(id).parquet"), rows("$(id)-examples.parquet"), rows("$(id)-documents.parquet")) for id in
			["bbh", "finqa", "gsm8k", "ifeval", "mmlu_pro", "multipl_e_julia", "pubmedqa", "scidocs", "scifact", "truthfulqa"]] == [
			("bbh", 6511, 81, 0), ("finqa", 1147, 883, 0), ("gsm8k", 1319, 7473, 0), ("ifeval", 541, 0, 0),
			("mmlu_pro", 12032, 70, 0), ("multipl_e_julia", 159, 0, 0), ("pubmedqa", 500, 500, 0), ("scidocs", 1000, 0, 25657),
			("scifact", 300, 0, 5183), ("truthfulqa", 817, 0, 0)]
		@test isfile(joinpath(folder, "LICENCES.md"))
	end
end
