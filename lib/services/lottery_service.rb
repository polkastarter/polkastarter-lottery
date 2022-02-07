require 'models/participant'
require 'pry'

class LotteryService
  # input
  attr_reader :seed        # optional  e.g: 12345678
  attr_reader :max_winners # mandatory e.g: 1000
  attr_reader :balances    # mandatory e.g: {'0x71C7656EC7ab88b098defB751B7401B5f6d8976F' => 3000}

  # output
  attr_reader :participants # only the eligible participants
  attr_reader :winners      # only winners
  attr_reader :all_tickets  # number of tickets

  def initialize(balances:, max_winners:, seed: nil)
    @balances      = balances
    @max_winners   = max_winners
    @winners       = []
    @seed          = seed || Random.new_seed

    srand @seed
  end

  def run
    @participants = balances.map { |address, balance| Participant.new address: address, balance: balance }
    @participants = @participants.select(&:eligible?).sort # sorted by balance
    @all_tickets  = @participants.sum(&:tickets)

    return @winners = @participants if @participants.size <= max_winners

    while @winners.size < max_winners
      exclude_winners_for_next_round unless @winners.empty?

      @winners += calculate_winners
      @winners  = @winners.first max_winners
    end

    @winners
  end

  private

  def exclude_winners_for_next_round
    @participants.reject! { |participant| @winners.include? participant }
  end

  def calculate_winners
    participants.each { |participant| participant.calculate_probability all_tickets }

    winners = participants.select { |p| p.winner? }
    winners = winners.sort { |p1, p2| p1.drew_probability <=> p2.drew_probability }
    winners = winners.first max_winners

    winners
  end
end
