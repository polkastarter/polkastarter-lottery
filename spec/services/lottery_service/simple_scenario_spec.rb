require 'spec_helper'
require 'csv'
require_relative '../../../lib/services/lottery_service'

RSpec.describe LotteryService do
  let(:service) { described_class.new(balances: balances, max_winners: 1_000) }

  context 'given a specific context' do
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

    let(:balances) {
      {
        '0x111' => 249,    # not enough balance
        '0x222' => 250,    # eligible
        '0x333' => 1_000,  # eligible
        '0x444' => 3_000,  # eligible
        '0x555' => 3_000,  # eligible
        '0x666' => 30_000, # eligible
      }
    }

    describe '#tickets' do
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
          '0x666 -> 150.0'
        ])
      end
    end

    describe '#all_tickets' do
      it 'returns the total number of tickets' do
        service.run

        expect(service.all_tickets).to eq(183.0)
      end
    end

    describe '#probabilites' do
      it 'calculates the right number of tickets for each participant' do
        service.run

        all_tickets = service.all_tickets
        service.participants.each do |participant|
          participant.calculate_probability all_tickets
        end

        probabilities = service.participants.map do |participant|
          "#{participant.address} -> #{participant.probability.round(4)}"
        end

        expect(probabilities).to match_array([
          '0x222 -> 0.0055', # =   1.0 ticket  / 183 total tickets =  0.55%
          '0x333 -> 0.024',  # =   4.0 tickets / 183 total tickets =  2.40%
          '0x444 -> 0.0754', # =  13.8 tickets / 183 total tickets =  7.54%
          '0x555 -> 0.0754', # =  13.8 tickets / 183 total tickets =  7.54%
          '0x666 -> 0.8197'  # = 150.0 tickets / 183 total tickets = 81.87%
        ])
      end
    end

    describe '#participants' do
      it 'returns the list of all eligible participants' do
        service.run

        expect(service.participants.map(&:address)).to match_array(%w(
          0x222
          0x333
          0x444
          0x555
          0x666
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
          '0x666 -> 1.25'
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
          '0x666'
        ])
      end

      context 'given 1 max winner' do
        let(:max_winners) { 1 }

        include_examples('theoretical probability', {
          "0x222" => 0.0055, #  0.55% expected
          "0x333" => 0.0240, #  2.40% expected
          "0x444" => 0.0754, #  7.54% expected
          "0x555" => 0.0754, #  7.54% expected
          "0x666" => 0.8197  # 81.97% expected
        })
      end

      context 'given 2 max winners' do
        let(:max_winners) { 2 }

        include_examples('theoretical probability', {
          "0x222" => 0.0313, #  3.13% expected
          "0x333" => 0.1374, # 13.74% expected
          "0x444" => 0.4266, # 42.66% expected
          "0x555" => 0.4266, # 42.66% expected
          "0x666" => 0.9781  # 97.81% expected
        })
      end

      context 'given 3 max winners' do
        let(:max_winners) { 3 }

        include_examples('theoretical probability', {
          "0x222" => 0.0787, #  7.87% expected
          "0x333" => 0.3296, # 32.96% expected
          "0x444" => 0.7966, # 79.66% expected
          "0x555" => 0.7966, # 79.66% expected
          "0x666" => 0.9987  # 99.87% expected
        })
      end

      context 'given 4 max winners' do
        let(:max_winners) { 4 }

        include_examples('theoretical probability', {
          "0x222" => 0.21150, # 21.150% expected
          "0x333" => 0.83584, # 83.584% expected
          "0x444" => 0.97634, # 97.634% expected
          "0x555" => 0.97634, # 97.634% expected
          "0x666" => 0.99980  # 99.998% expected
        })
      end

      context 'given 5 max winners' do
        let(:max_winners) { 5 }

        include_examples('theoretical probability', {
          "0x222" => 1.0, # 100% expected
          "0x333" => 1.0, # 100% expected
          "0x444" => 1.0, # 100% expected
          "0x555" => 1.0, # 100% expected
          "0x666" => 1.0  # 100% expected
        })
      end
    end
  end
end
