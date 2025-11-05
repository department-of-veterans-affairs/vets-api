# frozen_string_literal: true

require 'burials/pdf_fill/sections/section_04'

describe Burials::PdfFill::Section4 do
  describe 'set_state_to_no_if_national' do
    context 'with a regular location of death' do
      let(:form_data) do
        {
          'nationalOrFederal' => true
        }
      end

      it 'returns the directly mapped location' do
        described_class.new.set_state_to_no_if_national(form_data)
        expect(form_data['cemetaryLocationQuestion']).to eq('none')
      end
    end
  end
end
