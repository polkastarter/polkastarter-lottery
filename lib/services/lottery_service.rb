require 'models/participant'
require 'services/xorshift_service'

class LotteryService
  # input
  attr_reader :seed        # optional  e.g: 12345678
  attr_reader :max_winners # mandatory e.g: 1000
  attr_reader :balances    # mandatory e.g: { 12345 => 3000} # { application_id => pols_power }

  # output
  attr_reader :participants # only the eligible participants, sorted by the final probability
  attr_reader :not_eligible # only the not eligible participants (without balance)
  attr_reader :winners      # winners

  def initialize(balances:, max_winners:, seed: nil)
    @balances      = balances
    @max_winners   = max_winners
    @winners       = []
    @seed          = seed
    @xorshift      = XorshiftService.new @seed
  end

  def run
    @participants = balances.map { |identifier, balance| Participant.new identifier: identifier, balance: balance, xorshift: @xorshift }
    @participants = @participants.sort_by { |participant| participant.identifier }
    @not_eligible = @participants.reject &:eligible?
    @participants.select! &:eligible?
    @participants.sort!

    @winners = participants.first max_winners
  end
end
