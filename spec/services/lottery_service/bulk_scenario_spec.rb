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

  context 'given holders read from a CSV file with 32 911 holders' do
    let(:past_winners) { [] }
    let(:recent_winners) { [] }
    let(:blacklist) {
      ['0x000e8c608473dcee93021eb1d39fb4a7d7e7d780',
       '0x01b318b893cd822ea4876db2873f2add4d21588c',
       '0x01b5f0a5df18abd3155d717217839a5aeee3f30b']
    }
    let(:balances) {
      csv = CSV.read('spec/fixtures/holders.csv', headers: true)
      csv.map { |holder| [holder['address'], holder['pols_balance'].to_f] }.to_h
    }

    describe '#run' do
      it 'runs and generates an expected number of participants, of winners and intermediate sizes' do
        service.run

        expect(service.all_participants.size).to                       eq(32_908)
        expect(service.participants.size).to                           eq(13_282)
        expect(service.winners.size).to                                eq(500)
        expect(service.send(:top_holders).size).to                     eq(10) # fixed 10
        expect(service.send(:privileged_participants).size).to         eq(50) # i.e. 10% of 500
        expect(service.send(:shuffled_eligible_participants).size).to  eq(13_282)
      end
    end
  end
end
