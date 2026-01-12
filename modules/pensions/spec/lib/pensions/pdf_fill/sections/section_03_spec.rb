# frozen_string_literal: true

require 'pensions/pdf_fill/sections/section_03'

describe Pensions::PdfFill::Section3 do
  describe '#expand' do
    it 'puts overflow on line one' do
      long_place_of_separation = 'A very long place name that exceeds thirty-six characters'
      form_data = { 'placeOfSeparation' => long_place_of_separation }
      described_class.new.expand(form_data)

      expect(form_data['placeOfSeparationLineOne']).to eq(long_place_of_separation)
    end
  end
end
