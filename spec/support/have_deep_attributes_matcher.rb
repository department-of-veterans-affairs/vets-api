# frozen_string_literal: true
RSpec::Matchers.define :have_deep_attributes do
  match do |actual|
    expected_hash = expected.as_json
    actual_hash = actual.as_json
    expect(actual_hash).to eq(expected_hash)
  end

  failure_message do |actual|
    "expected object's attributes:\n\n #{actual.as_json} \n\n to deeply match: \n\n#{expected.as_json}"
  end
end
