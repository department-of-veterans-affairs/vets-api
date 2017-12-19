# frozen_string_literal: true
RSpec::Matchers.define :be_a_uuid do
  match do |actual|
    expect(actual).to match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/)
  end

  failure_message do |actual|
    "expected #{actual} to be a uuid and match /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/"
  end
end
