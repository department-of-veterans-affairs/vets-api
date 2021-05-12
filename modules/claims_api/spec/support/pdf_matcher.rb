# frozen_string_literal: true

require 'rspec/expectations'

RSpec::Matchers.define :match_pdf_content_of do |expected|
  match do |actual|
    actual_reader = PDF::Reader.new(actual)
    actual_pages = actual_reader.pages.size
    actual_text = actual_reader.pages.map(&:text)

    expected_reader = PDF::Reader.new(expected)
    expected_pages = expected_reader.pages.size
    expected_text = expected_reader.pages.map(&:text)

    # Check both page count and text content in case there are extraneous blank pages
    actual_pages == expected_pages && actual_text == expected_text
  end
  failure_message do |actual|
    "expected that content of #{actual} matches content of #{expected}"
  end
end
