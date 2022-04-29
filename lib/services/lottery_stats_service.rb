require_relative '../models/participant'
require 'services/lottery_service'

class LotteryStatsService
  # input
  attr_reader :lottery_service

  # output
  attr_reader :stats_by_tier

  def initialize(lottery_service)
    @lottery_service = lottery_service
  end

  def run
    @stats_by_tier = Participant::BALANCE_WEIGHTS.keys.inject({}) do |tiers, tier|
      tier_participants = lottery_service.participants.select { |participant| participant.tier == tier }.size
      tier_winners      = lottery_service.winners.select      { |winner| winner.tier == tier }.size

      tiers[tier] = {
        winners:      tier_winners,
        participants: tier_participants,
        percentage:   tier_winners.to_f / tier_participants
      }
      tiers
    end
  end
end
