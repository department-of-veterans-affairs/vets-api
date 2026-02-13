# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Burials do
  describe '.pdf_path' do
    context 'when burial_pdf_form_alignment flipper is disabled' do
      it 'returns the V1 PDF path' do
        allow(Flipper).to receive(:enabled?).with(:burial_pdf_form_alignment).and_return(false)

        expect(described_class.pdf_path).to eq('modules/burials/lib/burials/pdf_fill/pdfs/21P-530EZ.pdf')
      end
    end

    context 'when burial_pdf_form_alignment flipper is enabled' do
      it 'returns the V2 PDF path' do
        allow(Flipper).to receive(:enabled?).with(:burial_pdf_form_alignment).and_return(true)

        expect(described_class.pdf_path).to eq('modules/burials/lib/burials/pdf_fill/pdfs/21P-530EZ-V2.pdf')
      end
    end

    context 'when Flipper raises an error' do
      it 'propagates the error' do
        allow(Flipper).to receive(:enabled?).with(:burial_pdf_form_alignment).and_raise(StandardError)

        expect { described_class.pdf_path }.to raise_error(StandardError)
      end
    end
  end
end
