require 'date'

class Participant
  attr_reader :address
  attr_reader :balance
  attr_reader :recent_winner
  attr_reader :nft_rare_holder
  attr_reader :nft_common_holder

  def initialize(address:, balance:, recent_winner:, nft_rare_holder: false, nft_common_holder: false)
    @address = address.downcase
    @balance = (balance && balance >= 0) ? balance : 0 # guarding against nil or negative balances (corner cases that can arise 
                                                       # from the fact that snapshots are taken at slightly different moments 
                                                       # for the different chains)
    @recent_winner = recent_winner
    @nft_rare_holder = nft_rare_holder
    @nft_common_holder = nft_common_holder
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
    return true if nft_rare_holder

    tickets > 0 && !weight.nil? && !in_cooldown_period?
  end

  def in_cooldown_period?
    return false if nft_rare_holder || nft_common_holder || balance >= NO_COOLDOWN_MINIMUM_BALANCE

    recent_winner
  end

  def <=>(other)
    other.balance <=> self.balance # more balance comes first
  end
end
