# frozen_string_literal: true

require 'rspec/expectations'

RSpec::Matchers.define :match_pdf do |expected|
  match do |actual|
    normalize_page_data = lambda do |pages|
      # Write-to-write, the xobject keys & order may be different, so get the raw content & sort it
      # Using xobjects rather than page text lets us check against non-text fields like checkboxes, etc.
      pages.map { |pg| pg.xobjects.values.map(&:unfiltered_data).sort }
    end
    actual_reader = PDF::Reader.new(actual)
    actual_data = normalize_page_data.call actual_reader.pages

    expected_reader = PDF::Reader.new(expected)
    expected_data = normalize_page_data.call expected_reader.pages

    actual_reader.page_count == expected_reader.page_count && actual_data == expected_data
  end
  failure_message do |actual|
    "expected content of #{actual} to match #{expected}"
  end
end
