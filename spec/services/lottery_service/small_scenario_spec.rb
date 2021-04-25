require 'spec_helper'
require 'csv'
require_relative '../../../lib/services/lottery_service'

RSpec.describe LotteryService do
  let(:service) { described_class.new(balances: balances,
                                      recent_winners: recent_winners,
                                      past_winners: past_winners,
                                      blacklist: blacklist) }

  # NOTE: In this "small scenario" we exclude all the top holders and ignore the "privileged never winning" ratio,
  #       just to ease the probability calculations between all the "normal participants".
  #       The full scenario is tested on another file.
  context 'given a specific context' do
    before do
      stub_const 'LotteryService::MAX_WINNERS', 500
      stub_const 'LotteryService::TOP_N_HOLDERS', 0 # Ignore these on this context, as we have a really small set and we just want to test shuffle and weights
      stub_const 'LotteryService::PRIVILEGED_NEVER_WINNING_RATIO', 0 # Ignore these on this context, as we have a really small set and we just want to test shuffle and weights
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

    let(:past_winners) { ['0x555'] }
    let(:recent_winners) { ['0x666', '0x777'] }
    let(:blacklist) { ['0x888'] }
    let(:balances) {
      {
        '0x111' => 249,           # not enough balance
        '0x222' => 250,           # eligible. never participated
        '0x333' => 1_000,         # eligible. never participated
        '0x444' => 3_000,         # eligible. never participated
        '0x555' => 3_000,         # eligible. previous winner.
                                  # So, it would not be used in the calculation of the privileged participants
                                  # However, in these simple scenario of tests we're ignoring it
                                  # because we have PRIVILEGED_NEVER_WINNING_RATIO set to 0
        '0x666' => 3_000,         # excluded. previous participant
        '0x777' => 30_000,        # eligible. previous participant.
                                  # no cooldown (i.e. would be excluded, but is eligible because has >= 30 000 POLS
        '0x888' => 1_000_000_000, # always excluded. e.g: a Polkastarter team address, an exchange, etc
      }
    }

    describe '#participants' do
      it 'calculates the right number of tickets for each participant' do
        service.run

        tickets = service.participants.map do |participant|
          "#{participant.address} -> #{participant.tickets.round(4)}"
        end

        expect(tickets).to match_array([
          '0x222 -> 1.0',
          '0x333 -> 4.4',
          '0x444 -> 13.8',
          '0x555 -> 13.8',
          '0x777 -> 150.0'
        ])
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
          '0x777'
        ])
      end

      it 'correctly shuffles participants based on theirs weights' do
        top_winners = []
        number_of_experiments = 100_000

        # Run experiments (and get only the top winner to ease calculations) because complex rules do not appy on this context
        number_of_experiments.times do
          service.run
          top_winners << service.winners.first.address
        end

        # Calulcate probabilities
        probabilities = top_winners.count_by { |p| p }.map do |address, count|
          [address, count / number_of_experiments.to_f]
        end.to_h

        # Calculate if all addresses match the expected probability
        error_margin = 0.01
        expected_probabilities = {
          "0x222" => 0.110,
          "0x333" => 0.174,
          "0x444" => 0.211,
          "0x555" => 0.211,
          "0x777" => 0.291
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
