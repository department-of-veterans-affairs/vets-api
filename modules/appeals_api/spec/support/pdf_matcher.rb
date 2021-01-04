# frozen_string_literal: true

require 'rspec/expectations'

RSpec::Matchers.define :match_pdf do |expected|
  match do |actual|
    actual_text = PDF::Reader.new(actual).pages.map(&:text)
    expected_text = PDF::Reader.new(expected).pages.map(&:text)
    actual_text == expected_text
  end
  failure_message do |actual|
    "expected that content of #{actual} matches content of #{expected}"
  end
end
