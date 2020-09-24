# frozen_string_literal: true

require 'rspec/expectations'

RSpec::Matchers.define :eq_at_path do |path, expected|
  match do |actual|
    parsed_xml = Ox.parse(actual)
    actual_value = parsed_xml.locate(path).first
    actual_value == expected
  end
end

RSpec::Matchers.define :eq_text_at_path do |path, expected|
  match do |actual|
    parsed_xml = Ox.parse(actual)
    actual_value = parsed_xml.locate(path).first.nodes.first
    actual_value == expected
  end
end

RSpec::Matchers.define :match_at_path do |path, expected|
  match do |actual|
    parsed_xml = Ox.parse(actual)
    actual_value = parsed_xml.locate(path).first
    actual_value =~ expected
  end
end
