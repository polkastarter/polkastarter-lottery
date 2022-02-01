require 'spec_helper'
require 'csv'
require_relative '../../../lib/services/lottery_service'

RSpec.describe LotteryService do
  let(:service) { described_class.new(balances: balances,
                                      blacklist: blacklist,
                                      max_winners: LotteryService::DEFAULT_MAX_WINNERS,
                                      nft_rare_holders: nft_rare_holders) }

  # NOTE: In this "small scenario" we exclude all the top holders and ignore the "privileged never winning" ratio,
  #       just to ease the probability calculations between all the "normal participants".
  #       The full scenario is tested on another file.
  context 'given a specific context' do
    before do
      stub_const 'LotteryService::DEFAULT_MAX_WINNERS', 500
      stub_const 'LotteryService::DEFAULT_TOP_N_HOLDERS', 0 # Ignore these on this context, as we have a really small set and we just want to test shuffle and weights
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

    let(:blacklist)      { ['0x888'] }
    let(:nft_rare_holders) { ['0x010'] }
    let(:balances) {
      {
        '0x111' => 249,           # not enough balance
        '0x222' => 250,           # eligible. never participated
        '0x333' => 1_000,         # eligible. never participated
        '0x444' => 3_000,         # eligible. never participated
        '0x555' => 3_000,         # eligible. never participated
        '0x777' => 30_000,        # eligible
        '0x888' => 1_000_000_000, # always excluded. e.g: a Polkastarter team address, an exchange, etc,
        '0x010' => 0              # eligible. has 0 POLS, but has a rare NFT
      }
    }

    describe '#tickets' do
      it 'calculates the right number of tickets for each participant' do
        service.run

        tickets = service.participants.map do |participant|
          "#{participant.address} -> #{participant.tickets.round(4)}"
        end

        expect(service.participants.sum(&:tickets)).to eq(183.0)
        expect(tickets).to match_array([
          '0x222 -> 1.0',
          '0x333 -> 4.4',
          '0x444 -> 13.8',
          '0x555 -> 13.8',
          '0x777 -> 150.0',
          # 0x010 do not appear because is a nft tier 1 holder, so always wins
        ])
      end
    end

    describe '#eligibles' do
      it 'returns the list of all eligible participants' do
        service.run

        expect(service.eligibles.map(&:address)).to match_array(%w(
          0x222 0x333 0x444 0x555 0x777 0x010
        ))
      end
    end

    describe '#weights' do
      it 'calculates the right weights' do
        service.run

        weights = service.participants.map do |participant|
          "#{participant.address} -> #{participant.weight}"
        end

        expect(weights).to match_array([
          '0x222 -> 1.0',
          '0x333 -> 1.1',
          '0x444 -> 1.15',
          '0x555 -> 1.15',
          '0x777 -> 1.25'
          # 0x010 do not appear because is a nft tier 1 holder, so always wins
        ])
      end
    end

    describe '#winners' do
      it 'returns the winners only ' do
        service.run

        expect(service.winners.map(&:address)).to match_array([
          '0x222',
          '0x333',
          '0x444',
          '0x555',
          '0x777',
          '0x010'
        ])
      end

      it 'correctly shuffles participants based on theirs weights' do
        # Note that we're only getting the first winner on each exoerimenta,
        # because we just want to calculate probabilities for each of them
        stub_const 'LotteryService::MAX_WINNERS', 1

        top_winners = []
        number_of_experiments = 50_000

        # Run experiments
        puts ""
        experiments = []
        number_of_experiments.times do |index|
          service = described_class.new(balances: balances,
                                        blacklist: blacklist,
                                        max_winners: 1)
          service.run
          experiments << service.winners.map(&:address)

          puts " performed experiment number #{index} of #{number_of_experiments} for a simple scenario" if index % (10_000) == 0
        end

        # Calulcate probabilities
        occurences = experiments.flatten.count_by { |address| address }
        probabilities = occurences.transform_values { |value| value.to_f / number_of_experiments }

        # Calculate if all addresses match the expected probability
        error_margin = 0.01
        expected_probabilities = {
          "0x222" => 0.0055, #  0.6% expected
          "0x333" => 0.0240, #  2.4% expected
          "0x444" => 0.0754, #  7.5% expected
          "0x555" => 0.0754, #  7.5% expected
          "0x777" => 0.8197  # 81.9% expected
        }
        all_true = probabilities.all? do |address, probability|
          probability >= expected_probabilities[address] - error_margin &&
          probability <= expected_probabilities[address] + error_margin
        end

        # Veredict
        expect(probabilities.values.sum).to eq(1)
        expect(all_true).to be_truthy
      end
    end
  end
end
