# frozen_string_literal: true

require 'pensions/pdf_fill/sections/section_06'

describe Pensions::PdfFill::Section6 do
  describe '#marital_status_to_radio' do
    it 'returns correct radio value for marital status' do
      expect(described_class.new.marital_status_to_radio('MARRIED')).to eq(0)
      expect(described_class.new.marital_status_to_radio('SEPARATED')).to eq(1)
      expect(described_class.new.marital_status_to_radio('SINGLE')).to eq(2)
    end
  end

  describe '#reason_for_current_separation_to_radio' do
    it 'returns correct radio value for current separation reasons' do
      expect(described_class.new.reason_for_current_separation_to_radio('MEDICAL_CARE')).to eq(0)
      expect(described_class.new.reason_for_current_separation_to_radio('RELATIONSHIP')).to eq(1)
      expect(described_class.new.reason_for_current_separation_to_radio('LOCATION')).to eq(2)
      expect(described_class.new.reason_for_current_separation_to_radio('OTHER')).to eq(3)
      expect(described_class.new.reason_for_current_separation_to_radio('')).to eq('Off')
    end
  end
end
