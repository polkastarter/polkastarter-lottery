require 'date'

class Participant
  attr_reader :address
  attr_reader :balance
  attr_reader :recently_participated

  def initialize(address:, balance:, recently_participated:)
    @address = address.downcase
    @balance = balance || 0
    @recently_participated = recently_participated
  end

  TICKET_PRICE = 250.freeze                   # e.g: 100 means 1 ticket = 100 POLS
  NO_COOLDOWN_MINIMUM_BALANCE = 30_000.freeze # minimum balance to avoid cooldown
  BALANCE_WEIGHTS = {                         #  e.g: { 1000 => 1.1 } means 1000 POLS weigths 1.1
    0      => 0.00,
    250    => 1.00,
    1_000  => 1.10,
    3_000  => 1.15,
    10_000 => 1.20,
    30_000 => 1.25
  }.freeze

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
    tickets > 0 && !weight.nil? && !in_cooldown_period?
  end

  def in_cooldown_period?
    return false if balance >= NO_COOLDOWN_MINIMUM_BALANCE

    recently_participated
  end

  def <=>(other)
    other.balance <=> self.balance # more balance comes first
  end
end
