require 'spec_helper'
require 'csv'
require_relative '../../../lib/services/lottery_service'
require_relative '../../../lib/services/lottery_stats_service'

RSpec.describe LotteryService do
  before do
    stub_const 'Participant::TICKET_PRICE', 250
    stub_const 'Participant::BALANCE_WEIGHTS', {
      0      => 0.00,
      250    => 1.00,
      1_000  => 1.10,
      3_000  => 1.15,
      10_000 => 1.20,
      30_000 => 1.25
    }
  end

  before do
    skip if ENV['SKIP_BULK_SPECS']
  end

  let(:max_winners) { 1_000 }
  let(:service) { described_class.new(balances: balances, max_winners: max_winners) }

  context 'given holders read from a CSV file with holders' do
    let(:balances) {
      csv = CSV.read('spec/fixtures/holders.csv', headers: true)
      csv.map { |holder| [holder['address'], holder['pols_balance'].to_f] }.to_h
    }

    describe '#run' do
      it 'runs and generates an expected number of participants, of winners and intermediate sizes' do
        service.run

        expect(service.participants.size).to eq(18_533) # eligible participants only
        expect(service.winners.size).to eq(max_winners)
      end

      def stats_for(tier_stats, number_of_experiments)
        "#{tier_stats[:percentage].round(1)}% (#{tier_stats[:winners]} number of wins of a total of #{tier_stats[:participants]} participants in all experiments)"
      end

      it 'runs and generates the expected probabilites for some key holders' do
        number_of_experiments = 50_000
        error = 0.25

        # Run experiments
        experiments = []
        experiments_output = []
        tiers_experiments = {}
        start_at = Time.now.to_f

        puts ""
        puts "Running #{number_of_experiments} experiments, each of them with #{max_winners} max winners..."
        number_of_experiments.times do |index|
          timestamp = Time.now.to_f

          puts "start"
          service.run
          puts "end"
          experiments << service.winners.map(&:address)

          # Collect tier stats to show at the end
          stats_service = LotteryStatsService.new(service)
          stats_service.run
          stats_by_tier = stats_service.stats_by_tier

          tiers_experiments.deep_merge!(stats_by_tier) { |key, v1, v2| v1 + v2 }
          tiers_experiments.each do |tier, stats|
            tiers_experiments[tier][:percentage] = stats[:winners].to_f / stats[:participants] * 100
          end

          # Write output to CSV
          service.winners.each do |winner|
            experiments_output << [index, winner.address, winner.balance, winner.weight, winner.tier, winner.tickets]
          end

          expect(service.winners.size).to eq(max_winners)
          puts "#{service.winners.size} winners for experiment #{index}"

          time_diff = Time.now.to_f - timestamp
          puts " performed experiment number #{index} of #{number_of_experiments} for a bulk scenario [last experiment executed in #{time_diff.round(2)} seconds]" if index % 10 == 0
        end
        puts "Total run time: #{(Time.now.to_f - start_at).round(2)} seconds"

        # Write output to CSV
        CSV.open('experiments_output.csv', 'w') do |csv|
          csv << %w(experiment address balance weight tier tickets)
          csv << experiments_output.each { |row| csv << row }
        end

        # Calulcate probabilities
        occurences = experiments.flatten.count_by { |address| address }
        probabilities_hash = occurences.transform_values { |value| value.to_f / number_of_experiments }
        probabilities_array = probabilities_hash.sort_by { |address, probability| probability }.reverse

        # Print Statistics
        puts ""
        puts "Probabilities for #{number_of_experiments} experiments (#{1_000} winners on each) over a total of #{balances.count} participants with a ticket price of #{Participant::TICKET_PRICE} POLS:"
        puts " * <250 POLS: #{stats_for(tiers_experiments[0], number_of_experiments)}"
        puts " * 250+ POLS: #{stats_for(tiers_experiments[250], number_of_experiments)}"
        puts " * 1k+ POLS:  #{stats_for(tiers_experiments[1_000], number_of_experiments)}"
        puts " * 3k+ POLS:  #{stats_for(tiers_experiments[3_000], number_of_experiments)}"
        puts " * 10k+ POLS: #{stats_for(tiers_experiments[10_000], number_of_experiments)}"
        puts " * 30k+ POLS: #{stats_for(tiers_experiments[30_000], number_of_experiments)}"

        # Print tier probabilities
        puts ""
        puts "Tier Probabilities:"
        puts "Tier 0   POLS: #{tiers_experiments[0][:percentage]}"
        puts "Tier 250 POLS: #{tiers_experiments[250][:percentage]}"
        puts "Tier 1k  POLS: #{tiers_experiments[1_000][:percentage]}"
        puts "Tier 3k  POLS: #{tiers_experiments[3_000][:percentage]}"
        puts "Tier 10k POLS: #{tiers_experiments[10_000][:percentage]}"
        puts "Tier 30k POLS: #{tiers_experiments[30_000][:percentage]}"

        # Final veredict
        expect(probabilities_hash.values.sum).to eq(1_000)

        # Expect specific percentage of winners per each tier
        # TODO: expect(tiers_experiments[0][:percentage]).to be_nan
        # TODO: expect(tiers_experiments[250][:percentage]).to    be_around(0.96,  error)
        # TODO: expect(tiers_experiments[1_000][:percentage]).to  be_around(4.15,  error)
        # TODO: expect(tiers_experiments[3_000][:percentage]).to  be_around(10.25, error)
        # TODO: expect(tiers_experiments[10_000][:percentage]).to be_around(37.70, error)
        # TODO: expect(tiers_experiments[30_000][:percentage]).to be_around(76.15, error)
      end
    end
  end
end
