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
        expect(service.send(:shuffled_eligible_participants).size).to  eq(5_204)
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
        number_of_experiments = 2_000
        error = 0.015

        # Run experiments
        experiments = []
        number_of_experiments.times do
          service.run
          experiments << service.winners.map(&:address)
        end

        # Calulcate probabilities
        occurences = experiments.flatten.count_by { |address| address }
        probabilities_hash = occurences.transform_values { |value| value.to_f / number_of_experiments }
        probabilities_array = probabilities_hash.sort_by { |address, probability| probability }.reverse

        # Check if all summed cprobabilites give the same amount as winners
        expect(probabilities_hash.values.sum).to eq(500.0)

        # Only 10 top holders have 100% probability to enter. The 11th top holder doesn't
        expect(probabilities_array.first(11)).to match_array([
          ["0xa910f92acdaf488fa6ef02174fb86208ad7722ba", 1.0],
          ["0x36dc5e71304a3826c54ef6f8a19c2c4160e8ce9c", 1.0],
          ["0x6cc5f688a315f3dc28a7781717a9a798a59fda7b", 1.0],
          ["0xe93381fb4c4f14bda253907b18fad305d799241a", 1.0],
          ["0xea498641e67e0cc6b4fa89996e76220cfaec1611", 1.0],
          ["0xdd2aa97fb05ae47d1227faac488ad8678e8ea4f2", 1.0],
          ["0xc97d35dc801e6c16642b9e8b76d4ba26f30f72a6", 1.0],
          ["0x8a1ba492c2a0b5af4c910a70d53bf8bb76c9a4c0", 1.0],
          ["0xffa98a091331df4600f87c9164cd27e8a5cd2405", 1.0],
          ["0xc4ccdf87ad582639489da79726af1d001d244f76", 1.0],
          [be_a(String), a_value < 1.0]
        ])

        puts ""
        puts "Probabilities for #{number_of_experiments} experiments (#{LotteryService::MAX_WINNERS} winners on each) over a total of #{balances.count} holders:"
        puts " * Top #{LotteryService::TOP_N_HOLDERS} holders: 100%"

        # Check if specific-key addresses match the expected probability
        address = '0x4bb9f0008b7d69fd896a85a0652304502e6bc4a2'
        expect(balances[address]).to eq(249.0)
        expect(probabilities_hash[address]).to be_nil
        puts " * <250 POLS: 0%"

        address = '0x34244790665c5d6d03673a0cb6dc04e708d7f2fc'
        expect(balances[address]).to eq(251.0)
        expect(probabilities_hash[address]).to be_around(0.0075, error: error)
        puts " * 250+ POLS: #{(probabilities_hash[address] * 100).round(1)}%"

        address = '0x6d51241f1ca020ef659f6e94f53708f0cf40ac53'
        expect(balances[address]).to eq(999.0)
        expect(probabilities_hash[address]).to be_around(0.012, error: error)

        address = '0x6b54dbdab957e4dcf952fcd8d0ae7bbf35a6941a'
        expect(balances[address]).to eq(1_000.0)
        expect(probabilities_hash[address]).to be_around(0.05, error: error)
        puts " * 1k+ POLS: #{(probabilities_hash[address] * 100).round(1)}%"

        address = '0x842bf6a05dffa2f04572e0b676d0d320cd90f03b'
        expect(balances[address]).to eq(1_100.0)
        expect(probabilities_hash[address]).to be_around(0.05, error: error)

        address = '0x83eeccdb1bec996bc1e732a0c0e354d7b768f51c'
        expect(balances[address]).to eq(3_000.0)
        expect(probabilities_hash[address]).to be_around(0.0915, error: error)
        puts " * 3k+ POLS: #{(probabilities_hash[address] * 100).round(1)}%"

        address = '0xad50d90b2bf0ad70b8bc05e7002f1486d4149e7b'
        expect(balances[address]).to eq(3_300.0)
        expect(probabilities_hash[address]).to be_around(0.09, error: error)

        address = '0x152e24dd10e0e5036cfde46157c911c11090db88'
        expect(balances[address]).to eq(10_100.0)
        expect(probabilities_hash[address]).to be_around(0.1235, error: error)
        puts " * 10k+ POLS: #{(probabilities_hash[address] * 100).round(1)}%"

        address = '0xa7188b8cbccd0bd566eeb346b9e8ce9768e150da'
        expect(balances[address]).to eq(29_100.844164041)
        expect(probabilities_hash[address]).to be_around(0.1235, error: error)

        address = '0x25043e1526bccd8ea36d09d3c70d9b45e6040728'
        expect(balances[address]).to eq(30_260.052781161)
        expect(probabilities_hash[address]).to be_around(0.153, error: error)
        puts " * 30k+ POLS: #{(probabilities_hash[address] * 100).round(1)}%"
      end
    end
  end
end
