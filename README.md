# Polkastarter Lottery

`polkastarter-lottery` is a gem that generates a list of winners that can participate on a Polkastarter Pool.
This is based on a set of criteria that aim to turn access to a Pool the most democratic and fair as possible, as well as transparent and fail-proof.

This gem is used by Polkastarter to generate lotteries.

# Installation

`gem install polkastarter-lottery`


# Basic usage

```ruby
balances       = { '0x111' => 3000, '0x222' => 1_000, '0x333' => 30_000 }
past_winners   = ['0x222', '0x333']
recent_winners = ['0x222']

service = LotteryService.new balances: balances,
                             recent_winners: recent_winners,
                             past_winners: past_winners,
                             blacklist: []
service.run
service.winners
```

# Run specs

```
bundle install
rspec
```

# Default settings

##### Price per ticket

`250 POLS`

##### Weights for each holder

```
*  < 250  POLS -> 0.00
*    250+ POLS -> 1.00
*  1 000+ POLS -> 1.10
*  3 000+ POLS -> 1.15
* 10 000+ POLS -> 1.20
* 30 000+ POLS -> 1.25 (cool down period is bypassed for these holders)
```

##### Cool down period

Typically, participants that won a lottery in the previous 7 days will enter a cool down period and will not be able to participate on any other Pool during those 7 days.

However 10% of them (randomly) will still be able to win and participate.

Also, holders with >= 30 000 POLS will also automatically bypass this cool down period and will be able to always participate.

##### Top 10 holders

Top 10 holders are always winners. They can always particiapte at any pool and also bypass the cool down period.
