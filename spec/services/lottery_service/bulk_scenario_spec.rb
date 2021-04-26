require 'spec_helper'
require 'csv'
require_relative '../../../lib/services/lottery_service'

RSpec.describe LotteryService do
  before do
    stub_const 'LotteryService::MAX_WINNERS', 500
    stub_const 'LotteryService::TOP_N_HOLDERS', 10
    stub_const 'LotteryService::PRIVILEGED_NEVER_WINNING_RATIO', 0.10
    stub_const 'Participant::TICKET_PRICE', 250
    stub_const 'Participant::NO_COOLDOWN_MINIMUM_BALANCE', 30_000
    stub_const 'Participant::BALANCE_WEIGHTS', {
      0      => 0.00,
      250    => 1.00,
      1_000  => 1.10,
      3_000  => 1.15,
      10_000 => 1.20,
      30_000 => 1.25
    }
  end

  let(:service) { described_class.new(balances: balances,
                                      recent_winners: recent_winners,
                                      past_winners: past_winners,
                                      blacklist: blacklist) }

  context 'given holders read from a CSV file with 5 806 real holders (snapshotted at 26.Apr.2021)' do
    let(:past_winners) { [] }
    let(:recent_winners) { [] }
    let(:blacklist) { [] }
    let(:balances) {
      csv = CSV.read('spec/fixtures/holders.csv', headers: true)
      csv.map { |holder| [holder['address'], holder['pols_balance'].to_f] }.to_h
    }

    describe '#run' do
      it 'runs and generates an expected number of participants, of winners and intermediate sizes' do
        service.run

        expect(service.all_participants.size).to                       eq(5_808)
        expect(service.participants.size).to                           eq(5_204)
        expect(service.send(:top_holders).size).to                     eq(10) # fixed 10
        expect(service.send(:privileged_participants).size).to         eq(50) # i.e. 10% of 500
        expect(service.winners.size).to                                eq(500)
      end

      # TODO: refactor to a custom matcher:
      def be_around(value, error: 0.01)
        a_value_between (value - error),
                        (value + error)
      end

      it 'runs and generates the expected probabilites for some key holders' do
        number_of_experiments = 100
        error = 0.015

        # Run experiments
        experiments = []
        winners_by_tier = {}
        participants_by_tier = {}
        percentage_by_tier = {}
        #tiers = Participant::BALANCE_WEIGHTS.keys

        number_of_experiments.times do |index|
          service.run
          experiments << service.winners.map(&:address)

          service.stats_by_tier.each do |tier, stats|
            winners_by_tier[tier] ||= 0
            winners_by_tier[tier] += stats[:winners]
          end
          service.stats_by_tier.each do |tier, stats|
            participants_by_tier[tier] ||= 0
            participants_by_tier[tier] += stats[:participants]

            percentage_by_tier[tier] = (winners_by_tier[tier].to_f / participants_by_tier[tier] * 100)
          end

          puts " performed experiment number #{index} of #{number_of_experiments} for a bulk scenario" if index % 10 == 0
        end

        # Calulcate probabilities
        occurences = experiments.flatten.count_by { |address| address }
        probabilities_hash = occurences.transform_values { |value| value.to_f / number_of_experiments }
        probabilities_array = probabilities_hash.sort_by { |address, probability| probability }.reverse

        # require 'pry'
        # binding.pry
        # nil

        # Statistics
        puts ""
        puts "Probabilities for #{number_of_experiments} experiments (#{LotteryService::MAX_WINNERS} winners on each) over a total of #{balances.count} holders:"
        puts " * Top #{LotteryService::TOP_N_HOLDERS} holders: 100%"
        puts " * <250 POLS: #{percentage_by_tier[0].round(1)}%"
        puts " * 250+ POLS: #{percentage_by_tier[250].round(1)}%"
        puts " * 1k+ POLS:  #{percentage_by_tier[1_000].round(1)}%"
        puts " * 3k+ POLS:  #{percentage_by_tier[3_000].round(1)}%"
        puts " * 10k+ POLS: #{percentage_by_tier[10_000].round(1)}%"
        puts " * 30k+ POLS: #{percentage_by_tier[30_000].round(1)}%"

        # Final veredict
        expect(probabilities_hash.values.sum).to eq(500.0)

        # Top 10 holders have 100% probability to enter
        top_n_holders = balances.first(10).map(&:first)
        top_n_holders.each do |address|
          expect(probabilities_hash[address]).to eq(1.0)
        end

        # Expect specific percentage of winners per each tier
        expect(percentage_by_tier[0]).to be_nan
        expect(percentage_by_tier[250]).to be_around(0.1000, error: error)
        expect(percentage_by_tier[250]).to be_around(0.1500, error: error)
        expect(percentage_by_tier[250]).to be_around(0.7606, error: error)
        expect(percentage_by_tier[250]).to be_around(0.2905, error: error)
        expect(percentage_by_tier[250]).to be_around(0.7756, error: error)
      end
    end
  end
end
