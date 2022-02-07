RSpec.configure do |config|
  RSpec::Matchers.define :be_around do |expected_value, error|
    match do |actual_value|
      actual_value >= expected_value - error &&
        actual_value <= expected_value + error
    end

    failure_message do |actual_value|
      "expected that #{actual_value} would be around [#{expected_value - error}, #{expected_value + error}] with a margin error of #{error}, but it failed by #{(actual_value - expected_value).abs}"
    end
  end
end
