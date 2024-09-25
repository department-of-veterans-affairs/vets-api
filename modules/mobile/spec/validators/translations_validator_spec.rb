# frozen_string_literal: true

require 'rails_helper'

# validations to ensure that translations file is not broken
RSpec.describe 'Translations Validation' do
  describe 'translations/en/common.json file' do
    let(:file) do
      Rails.root.join('modules', 'mobile', 'app', 'assets', 'translations', 'en', 'common.json')
    end

    it 'is formatted as expected' do
      line_count = file.readlines.count
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
  end
end
