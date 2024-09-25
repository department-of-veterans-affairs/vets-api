# frozen_string_literal: true

require 'rails_helper'

# validations to ensure that translations file is not broken
RSpec.describe 'Translations Validation' do
  describe 'translations/en/common.json file' do
    let(:file) do
      Rails.root.join('modules', 'mobile', 'app', 'assets', 'translations', 'en', 'common.json')
    end
    let(:line_count) { file.readlines.count }

    it 'is formatted as expected' do
      File.readlines(file).each_with_index do |line, i|
        case i
        when 0
          expect(line).to eq("{\n")
        when (line_count - 1)
          expect(line).to eq("}\n")
        when (line_count - 2)
          expect(line).to match(/^  ".+": ".+"$/)
        else
          expect(line).to match(/^  ".+": ".+",$/)
        end
      end
    end

    it 'closes all interpolation braces' do
      File.readlines(file).each_with_index do |line, i|
        next if i.zero? || i == line_count - 1
        next unless line.include?('{{')

        unclosed_double_braces_pattern = /\{\{(?![^{}]*\}\})/
        expect(line).not_to match(unclosed_double_braces_pattern)
      end
    end

    it 'is alphabetized' do
      keys = File.readlines(file)[1..-2].map { |line| line.strip.split(/\\": \\"/).first.downcase }
      expect(keys).to eq(keys.sort)
    end
  end
end
