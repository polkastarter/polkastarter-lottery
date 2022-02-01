require 'spec_helper'
require 'csv'
require_relative '../../../lib/services/lottery_service'

RSpec.describe LotteryService do
  before do
    stub_const 'LotteryService::DEFAULT_MAX_WINNERS', 20
    stub_const 'LotteryService::DEFAULT_TOP_N_HOLDERS', 10
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
                                      blacklist: blacklist,
                                      max_winners: LotteryService::DEFAULT_MAX_WINNERS) }

  context 'given a specific context' do
    let(:recent_winners) { ['0x006', '0x007', '0x020'] }
    let(:blacklist) { ['0x008'] }
    let(:balances) {
      {
        '0x001' =>    249, # should be excluded. not enough balance
        # ----------------
        '0x002' =>    250, # should be eligible. never participated
        '0x003' =>  1_000, # should be eligible. never participated
        '0x004' =>  3_000, # should be eligible. never participated
        '0x005' =>  3_000, # should be eligible.
        '0x006' =>  3_000, # should be excluded. recent winner (in a cool down period)
        '0x007' => 30_000, # should be eligible. recent winner (in a cool down period)
                           # no cooldown (i.e. would be excluded, but is eligible because has >= 30 000 POLS
        '0x008' => 99_999, # should be excluded (always). e.g: a Polkastarter team address, an exchange, etc
        '0x009' =>  5_000, # should be eligible. never participated
        '0x010' =>  5_000, # should be eligible. never participated
        '0x011' => 10_001, # should be eligible, as a normal participant, i.e. it is not a top holder
                           # because 0x007 has more balance, so this would be the 11th holder
        # ----------------
        '0x012' => 10_002, # should be eligible
        '0x013' => 10_003, # should be eligible
        '0x014' => 10_004, # should be eligible
        '0x015' => 10_005, # should be eligible
        '0x016' => 10_006, # should be eligible
        '0x017' => 10_007, # should be eligible
        '0x018' => 10_008, # should be eligible
        '0x019' => 10_009, # should be eligible
        '0x020' => 10_010, # should be excluded. recent winner (in a cool down period)
        '0x021' => 10_011, # should be excluded
        # ----------------
        '0x030' =>  3_000, # should be eligible. never participated
        '0x031' =>  3_000, # should be eligible. never participated
        '0x032' =>  3_000, # should be eligible. never participated
        '0x033' =>  3_000, # should be eligible. never participated
        '0x034' =>  3_000, # should be eligible. never participated
        '0x035' =>  3_000, # should be eligible. never participated
        '0x036' =>  3_000, # should be eligible. never participated
        '0x037' =>  3_000, # should be eligible. never participated
        '0x038' =>  3_000, # should be eligible. never participated
        '0x039' =>  3_000, # should be eligible. never participated
        '0x040' =>  3_000, # should be eligible. never participated
      }
    }

    describe '#top_holders' do
      it 'returns the correct top holders list' do
        service.run

        top_holders = service.send(:top_holders).map(&:address)

        expect(top_holders.size).to eq(10)
        expect(top_holders).to eq([ # Note: order matters here:
          '0x007',   # holds 30 000 POLS - top holder 1
          '0x021',   # holds 10 011 POLS - top holder 2
          # '0x020', # holds 10 010 POLS - it is excluded because is a recent winner (cool down period) so, not eligible
          '0x019',   # holds 10 009 POLS - top holder 3
          '0x018',   # holds 10 008 POLS - top holder 4
          '0x017',   # holds 10 007 POLS - top holder 5
          '0x016',   # holds 10 006 POLS - top holder 6
          '0x015',   # holds 10 005 POLS - top holder 7
          '0x014',   # holds 10 004 POLS - top holder 8
          '0x013',   # holds 10 003 POLS - top holder 9
          '0x012',   # holds 10 002 POLS - top holder 10
          # '0x011',   # holds 10 001 POLS - top holder 10
          # '0x009', # holds  5 000 POLS - it is not a top holder because it is the 11th holder
          # '0x010'  # holds  5 000 POLS - it is not a top holder because it is the 12th holder
        ])
      end
    end

    describe '#tickets' do
      it 'calculates the right number of tickets for each participant' do
        service.run

        tickets = service.participants.map do |participant|
          "#{participant.address} -> #{participant.tickets.round(4)}"
        end

        expect(tickets).to match_array([
          # 0x001            # is out because it doesnt have enough balance
          # -------------
          "0x002 -> 1.0",
          "0x003 -> 4.4",
          "0x004 -> 13.8",
          "0x005 -> 13.8",
          # 0x006            # is out because it is a recent winner 
          "0x007 -> 150.0",  # is present because has >= 30 000 POLS
          # 0x008            # is excluded because it a blacklisted address
          "0x009 -> 23.0",
          "0x010 -> 23.0",
          # -------------
          "0x011 -> 48.0",
          "0x012 -> 48.0",
          "0x013 -> 48.0",
          "0x014 -> 48.0",
          "0x015 -> 48.0",
          "0x016 -> 48.0",
          "0x017 -> 48.0",
          "0x018 -> 48.0",
          "0x019 -> 48.0",
          # 0x020            # is a recent winner, so it should not be eligible, thus has no tickets.
                             # However, in the end, as a top holder, exceptionally, it will be a winner
          "0x021 -> 48.0",
          # -------------
          "0x030 -> 13.8",
          "0x031 -> 13.8",
          "0x032 -> 13.8",
          "0x033 -> 13.8",
          "0x034 -> 13.8",
          "0x035 -> 13.8",
          "0x036 -> 13.8",
          "0x037 -> 13.8",
          "0x038 -> 13.8",
          "0x039 -> 13.8",
          "0x040 -> 13.8"
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
          # 0x001            # is out because it doesnt have enough balance
          # -------------
          "0x002 -> 1.0",
          "0x003 -> 1.1",
          "0x004 -> 1.15",
          "0x005 -> 1.15",
          # 0x006            # is out because it is a recent participant
          "0x007 -> 1.25",   # is present because has >= 30 000 POLS
          # 0x008            # is excluded because it a blacklisted address
          "0x009 -> 1.15",
          "0x010 -> 1.15",
          # -------------
          "0x011 -> 1.2",
          "0x012 -> 1.2",
          "0x013 -> 1.2",
          "0x014 -> 1.2",
          "0x015 -> 1.2",
          "0x016 -> 1.2",
          "0x017 -> 1.2",
          "0x018 -> 1.2",
          "0x019 -> 1.2",
          # 0x020            # is a recent winner, so it should not be eligible, thus has no tickets.
          #                  # However, in the end, as a top holder, exceptionally, it will be a winner
          "0x021 -> 1.2",
          # -------------
          "0x030 -> 1.15",
          "0x031 -> 1.15",
          "0x032 -> 1.15",
          "0x033 -> 1.15",
          "0x034 -> 1.15",
          "0x035 -> 1.15",
          "0x036 -> 1.15",
          "0x037 -> 1.15",
          "0x038 -> 1.15",
          "0x039 -> 1.15",
          "0x040 -> 1.15"
        ])
      end
    end

    describe '#winners' do
      it 'correctly shuffles participants based on theirs weights' do
        number_of_experiments = 10_000

        # Run experiments
        puts ""
        experiments = []
        number_of_experiments.times do |index|
          service.run
          experiments << service.winners.map(&:address)

          puts " performed experiment number #{index} of #{number_of_experiments} for a full scenario" if index % 1000 == 0
        end

        # Calulcate probabilities
        occurences = experiments.flatten.count_by { |address| address }
        probabilities = occurences.transform_values { |value| value.to_f / number_of_experiments }

        # Calculate if all addresses match the expected probability
        error_margin = 0.025
        expected_probabilities = {
          "0x001" => 0,
          # -------------
          "0x002" => 0.06,
          "0x003" => 0.22,
          "0x004" => 0.56,
          "0x005" => 0.56,
          "0x006" => 0.00,    # excluded because is a recent winner
          "0x007" => 1.00,    # always appear because is a top 10 holder
          "0x008" => 0.00,    # excluded because is a blacklisted address
          "0x009" => 0.75,
          "0x010" => 0.75,
          # -------------
          "0x011" => 0.93,    # holds a lot (almost the same as top 10 holders). however, has a little bit less probability because it is not a top 10 holder
          "0x012" => 1.00,    # always appear because is a top 10 holder 1
          "0x013" => 1.00,    # always appear because is a top 10 holder 2
          "0x014" => 1.00,    # always appear because is a top 10 holder 3
          "0x015" => 1.00,    # always appear because is a top 10 holder 4
          "0x016" => 1.00,    # always appear because is a top 10 holder 5
          "0x017" => 1.00,    # always appear because is a top 10 holder 6
          "0x018" => 1.00,    # always appear because is a top 10 holder 7
          "0x019" => 1.00,    # always appear because is a top 10 holder 8
          "0x020" => 1.00,    # always appear because is a top 10 holder 9
          "0x021" => 1.00,    # always appear because is a top 10 holder 10
          # -------------
          "0x030" => 0.56,
          "0x031" => 0.56,
          "0x032" => 0.56,
          "0x033" => 0.56,
          "0x034" => 0.56,
          "0x035" => 0.56,
          "0x036" => 0.56,
          "0x037" => 0.56,
          "0x038" => 0.56,
          "0x039" => 0.56,
          "0x040" => 0.56
        }

        # Calculate values
        puts "Results"
        probabilities.each do |address, probability|
          expected = expected_probabilities[address]

          low_margin  = expected - error_margin
          high_margin = expected + error_margin

          puts({
            address: address,
            expected: expected,
            probability: probability,
            error: (probability - expected).round(2),
            valid: probability.between?(low_margin, high_margin)
          })
        end

        all_true = probabilities.all? do |address, probability|
          expected = expected_probabilities[address]

          low_margin  = expected - error_margin
          high_margin = expected + error_margin

          probability.between?(low_margin, high_margin)
        end

        # Veredict
        expect(all_true).to be_truthy
      end
    end
  end
end
