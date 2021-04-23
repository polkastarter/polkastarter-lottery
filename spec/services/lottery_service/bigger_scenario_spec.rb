require 'spec_helper'
require 'csv'
require_relative '../../../lib/services/lottery_service'

RSpec.describe LotteryService do
  before do
    stub_const 'LotteryService::MAX_WINNERS', 20
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

  context 'given a specific context' do
    let(:past_winners) { ['0x005'] }
    let(:recent_winners) { ['0x006', '0x007', '0x020'] }
    let(:blacklist) { ['0x008'] }
    let(:balances) {
      {
        '0x001' =>    249, # should be excluded. not enough balance
        # ----------------
        '0x002' =>    250, # should be eligible. never participated
        '0x003' =>  1_000, # should be eligible. never participated
        '0x004' =>  3_000, # should be eligible. never participated
        '0x005' =>  3_000, # should be eligible. previous winner.
                           # so, it is not used in the calculation of the privileged participants
        '0x006' =>  3_000, # should be excluded. previous participant
        '0x007' => 30_000, # should be eligible. previous participant. 
                           # no cooldown (i.e. would be excluded, but is eligible because has >= 30 000 POLS
        '0x008' => 99_999, # should be excluded (always). e.g: a Polkastarter team address, an exchange, etc
        '0x009' =>  5_000, # should be eligible. never participated
        '0x010' =>  5_000, # should be eligible. never participated
        '0x011' => 10_001, # should be not eligible. not a top holder because 0x007 has more balance,
                           # so this would be the 11th holder
        # ----------------
        '0x012' => 10_002, # should be eligible. a top 10 holder. no cooldown (i.e. would be excluded, but is eligible because is top holder)
        '0x013' => 10_003, # should be eligible. a top 10 holder. no cooldown (i.e. would be excluded, but is eligible because is top holder)
        '0x014' => 10_004, # should be eligible. a top 10 holder. no cooldown (i.e. would be excluded, but is eligible because is top holder)
        '0x015' => 10_005, # should be eligible. a top 10 holder. no cooldown (i.e. would be excluded, but is eligible because is top holder)
        '0x016' => 10_006, # should be eligible. a top 10 holder. no cooldown (i.e. would be excluded, but is eligible because is top holder)
        '0x017' => 10_007, # should be eligible. a top 10 holder. no cooldown (i.e. would be excluded, but is eligible because is top holder)
        '0x018' => 10_008, # should be eligible. a top 10 holder. no cooldown (i.e. would be excluded, but is eligible because is top holder)
        '0x019' => 10_009, # should be eligible. a top 10 holder. no cooldown (i.e. would be excluded, but is eligible because is top holder)
        '0x020' => 10_010, # should be eligible. a top 10 holder. no cooldown (i.e. would be excluded, but is eligible because is top holder)
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
          '0x007', # holds 30 000 POLS
          '0x020', # holds 10 010 POLS
          '0x019', # holds 10 009 POLS
          '0x018', # holds 10 008 POLS
          '0x017', # holds 10 007 POLS
          '0x016', # holds 10 006 POLS
          '0x015', # holds 10 005 POLS
          '0x014', # holds 10 004 POLS
          '0x013', # holds 10 003 POLS
          '0x012', # holds 10 002 POLS
          # 0x011  # holds 10 001 POLS, so is out
        ])
      end
    end

    describe '#participants' do
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
          "0x007 -> 150.0",  # is present (event being a previous winner) because has >= 30 000 POLS
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
          # 0x006            # is out because it is a previous participant 
          "0x007 -> 1.25",   # is present (event being a previous participant) because has >= 30 000 POLS
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
        number_of_experiments = 50_000

        # Run experiments
        experiments = []
        number_of_experiments.times do
          service.run
          experiments << service.winners.map(&:address)
        end

        # Calulcate probabilities
        occurences = experiments.flatten.count_by { |address| address }
        probabilities = occurences.transform_values { |value| value.to_f / number_of_experiments }

        # Calculate if all addresses match the expected probability
        error_margin = 0.01
        expected_probabilities = {
          "0x001" => 0,
          # -------------
          "0x002" => 0.490,
          "0x003" => 0.539,
          "0x004" => 0.557,
          "0x005" => 0.519,
          "0x006" => 0.000, # excluded because is a recent winner
          "0x007" => 1.000, # always appear because is a top 10 holder
          "0x008" => 0.000, # excluded because is a 
          "0x009" => 0.561,
          "0x010" => 0.562,
          # -------------
          "0x011" => 0.581, # holds a lot (almost the same as top 10 holders).
                            # however, has less probability because it is not a top 10 holder
          "0x012" => 1.000, # always appear because is a top 10 holder
          "0x013" => 1.000, # always appear because is a top 10 holder
          "0x014" => 1.000, # always appear because is a top 10 holder
          "0x015" => 1.000, # always appear because is a top 10 holder
          "0x016" => 1.000, # always appear because is a top 10 holder
          "0x017" => 1.000, # always appear because is a top 10 holder
          "0x018" => 1.000, # always appear because is a top 10 holder
          "0x019" => 1.000, # always appear because is a top 10 holder
          "0x020" => 1.000, # always appear because is a top 10 holder
          # -------------
          "0x021" => 0.000,
          "0x022" => 0.000,
          "0x023" => 0.000,
          "0x024" => 0.000,
          "0x025" => 0.000,
          "0x026" => 0.000,
          "0x027" => 0.000,
          "0x028" => 0.000,
          "0x029" => 0.000,
          # -------------
          "0x030" => 0.560,
          "0x031" => 0.559,
          "0x032" => 0.562,
          "0x033" => 0.562,
          "0x034" => 0.561,
          "0x035" => 0.562,
          "0x036" => 0.564,
          "0x037" => 0.565,
          "0x038" => 0.565,
          "0x039" => 0.566,
          "0x040" => 0.557,
        }

        # For debugging purposes
        calcs = probabilities.map do |address, probability|
          expected = expected_probabilities[address]

          low_margin  = expected - error_margin
          high_margin = expected + error_margin

          [address, probability, expected, probability.between?(low_margin, high_margin)]
        end

        all_true = probabilities.all? do |address, probability|
          expected = expected_probabilities[address]

          low_margin  = expected - error_margin
          high_margin = expected + error_margin

          probability.between?(low_margin, high_margin)
        end

        # Veredict
        expect(probabilities.values.sum).to eq(20.0)
        expect(all_true).to be_truthy
      end
    end
  end
end
