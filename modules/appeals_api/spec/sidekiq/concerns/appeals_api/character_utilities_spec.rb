# frozen_string_literal: true

require 'rails_helper'

class CharacterUtilites
  include AppealsApi::CharacterUtilities
end

describe CharacterUtilites do
  describe '#transliterate_for_centralmail' do
    it '"collapses" ascii-compatible special characters' do
      expect(described_class.new.transliterate_for_centralmail('Jåñé')).to eq 'Jane'
    end

    it 'removes characters that are "uncollapsable" into the charset' do
      str = "_! O'/Reilly Anderson-Smith"
      expect(described_class.new.transliterate_for_centralmail(str)).to eq 'OReilly Anderson-Smith'
    end

    it 'strips whitespace from beginning and end' do
      str = '   so claustrophobic    '
      expect(described_class.new.transliterate_for_centralmail(str)).to eq 'so claustrophobic'
    end

    it 'only allows 50 characters' do
      expect(described_class.new.transliterate_for_centralmail('A' * 100).length).to eq 50
    end
  end
end
