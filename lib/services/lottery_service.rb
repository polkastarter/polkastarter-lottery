#require_relative '../models/participant'
#require File.dirname(__FILE__) + '/../models/participant'
require 'models/participant'
require 'pry'

class LotteryService
  attr_reader :balances           # e.g: { '0x71C7656EC7ab88b098defB751B7401B5f6d8976F' => 3000 }
  attr_reader :recent_winners     # e.g: ['0x71C7656EC7ab88b098defB751B7401B5f6d8976F']
  attr_reader :past_winners       # e.g: ['0x71C7656EC7ab88b098defB751B7401B5f6d8976F']
  attr_reader :blacklist          # e.g: ['0x71C7656EC7ab88b098defB751B7401B5f6d8976F']
  attr_reader :nft_rare_holders   # e.g: ['0x71C7656EC7ab88b098defB751B7401B5f6d8976F'] # rare NFT
  attr_reader :nft_common_holders # e.g: ['0x71C7656EC7ab88b098defB751B7401B5f6d8976F'] # common NFT

  attr_reader :all_participants # all candidates
  attr_reader :eligibles        # only eligible ones
  attr_reader :participants     # only the list of wallets that will be actually shuffled (i.e. excluding top holders and nft rare holders)
  attr_reader :winners          # only winners
  attr_reader :max_winners
  attr_reader :top_n_holders
  attr_reader :privileged_never_winning_ratio
  attr_reader :top_holders
  attr_reader :privileged_participants

  DEFAULT_MAX_WINNERS = 1_000.freeze
  DEFAULT_TOP_N_HOLDERS = 10.freeze
  DEFAULT_PRIVILEGED_NEVER_WINNING_RATIO = 0.0.freeze

  def initialize(balances:,
                 max_winners: DEFAULT_MAX_WINNERS,
                 top_n_holders: DEFAULT_TOP_N_HOLDERS,
                 privileged_never_winning_ratio: DEFAULT_PRIVILEGED_NEVER_WINNING_RATIO,
                 recent_winners: [],
                 past_winners: [],
                 blacklist: [],
                 nft_rare_holders: [],
                 nft_common_holders: [])
    @balances = balances
    @max_winners = max_winners
    @top_n_holders = top_n_holders
    @privileged_never_winning_ratio = privileged_never_winning_ratio
    @recent_winners = recent_winners
    @past_winners = past_winners.map &:downcase
    @blacklist = blacklist
    @nft_rare_holders = nft_rare_holders
    @nft_common_holders = nft_common_holders
  end

  def run
    @all_participants = build_participants.sort # sort desc by balance
    @eligibles        = all_participants.select(&:eligible?)
    @top_holders      = @eligibles.first top_n_holders
    @participants     = @eligibles.reject do |participant|
      top_holder?(participant) || participant.nft_rare_holder # top holders and nft1 holders are always excluded from shuffling because they will always enter
    end.sort # also order them by balance

    @privileged_participants = shuffled_privileged_participants

    @winners = calculate_winners.compact
  end

  # Only used for statistics and debugging
  def stats_by_tier
    Participant::BALANCE_WEIGHTS.keys.inject({}) do |tiers, tier|
      tier_participants = participants.select { |participant| participant.tier == tier }.size
      tier_winners      = winners.select      { |winner| winner.tier == tier }.size

      tiers[tier] = {
        winners:      tier_winners,
        participants: tier_participants,
        percentage:   tier_winners.to_f / tier_participants
      }
      tiers
    end
  end

  private

  def calculate_winners
    winners = []

    winners += top_holders
    winners += nft_rare_participants
    winners += privileged_participants
    winners += shuffled_eligible_participants

    winners.uniq.first(max_winners)
  end

  def top_holder?(participant)
    top_holders.include? participant.address
  end

  def shuffled_privileged_participants
    sample_size = max_winners * privileged_never_winning_ratio
    never_winning_participants.sample sample_size
  end

  def weighted_random_sample(participants)
    participants.max_by do |participant|
      rand ** (1.0 / participant.tickets)
    end
  end

  def shuffled_eligible_participants
    (max_winners * 5).times.map do
      weighted_random_sample(participants)
    end
  end

  def never_winning_participants
    participants.select { |participant| !past_winners.include? participant.address }
  end

  def nft_rare_participants
    eligibles.select { |participant| participant.nft_rare_holder }
  end

  def build_participants
    nft_rare_balances = nft_rare_holders.map { |addr| [addr, nil] }.to_h
    all_balances = balances.merge(nft_rare_balances)

    all_balances.map do |address, balance|
      next if blacklist.include? address
      Participant.new address:           address,
                      balance:           balance,
                      recent_winner:     recent_winners.include?(address),
                      nft_rare_holder:   nft_rare_holders.include?(address),
                      nft_common_holder: nft_common_holders.include?(address)
    end.compact
  end
end
