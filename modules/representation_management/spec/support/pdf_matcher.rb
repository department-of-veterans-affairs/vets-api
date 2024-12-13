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

    @diffs = []

    actual_pages.times do |index|
      p "Page #{index + 1}:"
      if actual_text[index] != expected_text[index]
        @diffs << Diff::LCS.diff(actual_text[index], expected_text[index])
        p 'Start MISMATCH ' * 10
        p "Actual: #{actual_text[index]}"
        p "Expected: #{expected_text[index]}"
        p 'End MISMATCH ' * 10
      end
    end

    # Check both page count and text content in case there are extraneous blank pages
    actual_pages == expected_pages && actual_text == expected_text
  end
  failure_message do |actual|
    # "expected that content of #{actual} matches content of #{expected}"
    message = "expected that content of #{actual} matches content of #{expected}\n"
    @diffs.each_with_index do |diff, index|
      message += "Differences on page #{index + 1}:\n"
      diff.each do |change|
        message += change.to_s + "\n"
      end
    end
    message
  end
end
