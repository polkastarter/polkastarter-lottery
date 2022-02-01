

require 'spec_helper'
require 'csv'
require_relative '../../../lib/services/lottery_service'

RSpec.describe LotteryService do
  before do
    stub_const 'LotteryService::DEFAULT_MAX_WINNERS', 200
    stub_const 'LotteryService::DEFAULT_TOP_N_HOLDERS', 10
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

  context 'given holders read from a CSV file with holders' do
    let(:balances) {
      csv = CSV.read('spec/fixtures/holders.csv', headers: true)
      csv.map { |holder| [holder['address'], holder['pols_balance'].to_f] }.to_h
    }

    context 'given no seed numbers' do
      it 'generates different results' do
        service = LotteryService.new(balances: balances, max_winners: 100)
        service.run
        winners1 = service.winners.map(&:address)

        service = LotteryService.new(balances: balances, max_winners: 100)
        service.run
        winners2 = service.winners.map(&:address)

        expect(winners1).not_to eq(winners2)
      end
    end

    context 'given different seed numbers' do
      it 'generates different results' do
        service = LotteryService.new(balances: balances, max_winners: 100, seed: 111)
        service.run
        winners1 = service.winners.map(&:address)

        service = LotteryService.new(balances: balances, max_winners: 100, seed: 222)
        service.run
        winners2 = service.winners.map(&:address)

        expect(winners1).not_to eq(winners2)
      end
    end

    context 'given different seed numbers' do
      it 'generates different results' do
        service = LotteryService.new(balances: balances, max_winners: 100, seed: 111)
        service.run
        winners1 = service.winners.map(&:address)

        service = LotteryService.new(balances: balances, max_winners: 100, seed: 111)
        service.run
        winners2 = service.winners.map(&:address)

        expect(winners1).to eq(winners2)
      end
    end
  end
end
