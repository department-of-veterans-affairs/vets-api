# frozen_string_literal: true

require 'rails_helper'

# validations to ensure that translations file is not broken
RSpec.describe 'Translations Validation' do # rubocop:disable RSpec/DescribeClass
  describe 'translations/en/common.json file' do
    let(:file) { Rails.root.join('modules', 'mobile', 'app', 'assets', 'translations', 'en', 'common.json') }

    it 'is formatted as expected' do
      last_line_index = file.readlines.count - 1
      second_to_last_line_index = last_line_index - 1

      File.readlines(file).each_with_index do |line, i|
        case i
        when 0
          expect(line).to eq("{\n")
        when last_line_index
          expect(line).to eq("}\n")
        when second_to_last_line_index
          # no comma in second to last line
          expect(line).to match(/^  ".+": ".+"$/)
        else
          expect(line).to match(/^  ".+": ".+",$/)
        end
      end
    end

    it 'closes all interpolation braces' do
      File.readlines(file)[1..-2] do |line|
        unclosed_double_braces_pattern = /\{\{(?![^{}]*\}\})/
        expect(line).not_to match(unclosed_double_braces_pattern)
      end
    end

    it 'is alphabetized' do
      keys = File.readlines(file)[1..-2].map { |line| line.strip.split(/": "/).first.downcase }
      expect(keys).to eq(keys.sort)
    end
  end
end
