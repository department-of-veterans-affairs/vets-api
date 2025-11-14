# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'
require 'increase_compensation/pdf_fill/va218940v1'
require 'fileutils'
require 'tmpdir'
require 'timecop'

describe IncreaseCompensation::PdfFill::Section4 do
  describe '#education_highschool_bug_fix' do
    it 'attempt to fix a mapping bug with the checkboxes' do
      expect(described_class.new.education_highschool_bug_fix(9)).to eq(10)
      expect(described_class.new.education_highschool_bug_fix(10)).to eq(11)
      expect(described_class.new.education_highschool_bug_fix(11)).to eq(12)
      expect(described_class.new.education_highschool_bug_fix(12)).to eq('Off')
      expect(described_class.new.education_highschool_bug_fix(13)).to eq('')
    end
  end
end
