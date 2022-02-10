require 'models/participant'
require 'pry'

class LotteryService
  # input
  attr_reader :seed        # optional  e.g: 12345678
  attr_reader :max_winners # mandatory e.g: 1000
  attr_reader :balances    # mandatory e.g: { 12345 => 3000} # { application_id => pols_power }

  # output
  attr_reader :participants # only the eligible participants, sorted by the final probability
  attr_reader :winners      # winners

  def initialize(balances:, max_winners:, seed: nil)
    @balances      = balances
    @max_winners   = max_winners
    @winners       = []
    @seed          = seed || Random.new_seed

    srand @seed
  end

  def run
    @participants = balances.map { |address, balance| Participant.new address: address, balance: balance }
    @participants.select! &:eligible?
    @participants.sort!

    @winners = participants.first max_winners
  end
end
