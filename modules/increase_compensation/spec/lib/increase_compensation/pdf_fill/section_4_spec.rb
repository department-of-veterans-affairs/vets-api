# frozen_string_literal: true

require 'rails_helper'

describe IncreaseCompensation::PdfFill::Section4 do
  describe '#education_highschool_bug_fix' do
    it 'attempt to fix a mapping bug with the checkboxes' do
      expect(described_class.new.education_highschool_bug_fix(9)).to eq(0)
      expect(described_class.new.education_highschool_bug_fix(10)).to eq(1)
      expect(described_class.new.education_highschool_bug_fix(11)).to eq(2)
      expect(described_class.new.education_highschool_bug_fix(12)).to eq(3)
      expect(described_class.new.education_highschool_bug_fix(13)).to eq('Off')
    end
  end
end
