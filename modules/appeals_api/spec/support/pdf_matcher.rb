# frozen_string_literal: true

require 'rspec/expectations'

RSpec::Matchers.define :match_pdf do |expected_pdf_path|
  match do |actual_pdf_path|
    @actual = PDF::Reader.new(actual_pdf_path).pages.map(&:text).join
    @expected = PDF::Reader.new(expected_pdf_path).pages.map(&:text).join
    expect(actual).to eq(expected)
  end

  diffable
  attr_reader :actual, :expected
end
