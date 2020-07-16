# frozen_string_literal: true

require 'rspec/expectations'

RSpec::Matchers.define :match_pdf_content_of do |expected|
  match do |actual|
    PDF::Inspector::Text.analyze(actual).strings == PDF::Inspector::Text.analyze(expected).strings
  end
  failure_message do |actual|
    "expected that content of #{actual} matches content of #{expected}"
  end
end
