require 'date'

class Participant
  attr_reader :identifier
  attr_reader :balance

  def initialize(identifier:, balance:, xorshift: nil)
    @identifier = identifier
    @balance    = (balance && balance >= 0) ? balance : 0 # guarding against invalid balances
    @xorshift   = xorshift || XorshiftService.new
  end

  TICKET_PRICE = 250.freeze # e.g: 100 means 1 ticket = 100 POLS
  BALANCE_WEIGHTS = {       # e.g: { 1000 => 1.1 } means 1000 POLS weigths 1.1
    0      => 0.00,
    250    => 1.00,
    1_000  => 1.10,
    3_000  => 1.15,
    10_000 => 1.20,
    30_000 => 1.25
  }.freeze

  def dice
    @dice ||= @xorshift.next_float
  end

  def probability
    dice ** (1.0 / tickets) # reservoir sampling
  end

  def tickets
    (balance / TICKET_PRICE).to_i * weight
  end

  def weight
    @weight ||= BALANCE_WEIGHTS[tier]
  end

  def tier
    BALANCE_WEIGHTS.keys.select { |min_balance| min_balance <= balance }.last
  end

  def eligible?
    tickets > 0
  end

  def <=>(other)
    other.probability <=> self.probability
  end
end
