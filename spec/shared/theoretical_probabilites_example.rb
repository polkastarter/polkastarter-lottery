RSpec.shared_examples 'theoretical probability' do |theoretical_probability|
  let(:number_of_experiments) { 100_000 }
  let(:error_margin) { 0.025 }

  it 'tests against theoretical probability' do
    # Run experiments
    puts ""
    puts "Running #{number_of_experiments} experiments, each of them with #{max_winners} max winners..."
    experiments = []
    number_of_experiments.times do |index|
      # Note that we're only getting the first winner on each exoeriment, because we just want to calculate probabilities for each of them
      service = described_class.new(balances: balances, max_winners: max_winners)
      service.run
      experiments << service.winners.map(&:identifier)

      # puts " performed experiment number #{index} of #{number_of_experiments}" if index % (10_000) == 0
    end

    # Calulcate probabilities
    occurences       = experiments.flatten.count_by { |identifier| identifier } # e.g: { '0x222' => 30, '0x333' => 60, ... )
    total_occurences = occurences.values.sum
    probabilities    = occurences.transform_values { |value| value.to_f / number_of_experiments }

    # Calculate if all addresses match the expected probability
    puts "Input: Acceptable error margin: #{error_margin}"
    puts "Input: Expected probabilities: #{theoretical_probability}"
    puts "Output: Drew probabilities: #{probabilities}"
    puts "Output: Occurences: #{occurences}"
    puts "Output: Total occurences: #{total_occurences}"

    # Veredict
    expect(total_occurences).to eq(number_of_experiments * max_winners)
    expect(probabilities.values.sum).to eq(max_winners)
    probabilities.each do |identifier, probability|
      expect(probability).to be_around(theoretical_probability[identifier], error_margin)
    end
  end
end
