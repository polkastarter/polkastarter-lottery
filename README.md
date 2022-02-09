# Polkastarter Lottery

`polkastarter-lottery` is a gem that generates a list of winners that can participate on a Polkastarter Pool.
This is based on a set of criteria that aim to turn access to a Pool the most democratic and fair as possible, as well as transparent and fail-proof.

This gem is used by Polkastarter to generate lotteries.

Check [this blog post](https://blog.polkastarter.com/polkastarter-whitelists-just-got-a-whole-lot-better/) to understand the full mechanic for this lottery system.

# Installation

`gem install polkastarter-lottery`


# Basic usage

```ruby
balances = { '0x111' => 3000, '0x222' => 1_000, '0x333' => 30_000 }

service = LotteryService.new balances: balances,
                             max_winners: 1_000,
                             seed: 1234567890 # optional
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
* 30 000+ POLS -> 1.25
```

##### Top 10 holders

Top 10 holders are always winners. They can always particiapte at any pool and also bypass the cool down period.
