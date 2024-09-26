# frozen_string_literal: true

require 'rails_helper'

# the translations file we serve to the mobile front end is kept locally under git control and is edited in github.
# these validations act as a CI step to ensure that no mistakes were made when editing the file.
RSpec.describe 'Translations Validation' do # rubocop:disable RSpec/DescribeClass
  describe 'translations/en/common.json' do
    let(:file) { Rails.root.join('modules', 'mobile', 'app', 'assets', 'translations', 'en', 'common.json') }
    let(:translations) { file.readlines[1..-2] } # excludes braces

    it 'is formatted as expected' do
      last_line_index = file.readlines.count - 1
      second_to_last_line_index = last_line_index - 1

      file.each_line.with_index do |line, i|
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

    it 'does not contain unclosed interpolation braces' do
      translations.each do |line|
        unclosed_double_braces_pattern = /\{\{(?![^{}]*\}\})/
        expect(line).not_to match(unclosed_double_braces_pattern)
      end
    end

    it 'is alphabetized' do
      keys = translations.map { |line| line.strip.split(/": "/).first.downcase }
      expect(keys).to eq(keys.sort)
    end
  end
end
