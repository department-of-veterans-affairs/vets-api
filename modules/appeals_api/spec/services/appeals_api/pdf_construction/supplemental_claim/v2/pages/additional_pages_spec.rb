# frozen_string_literal: true

require 'rails_helper'

module AppealsApi::PdfConstruction::SupplementalClaim::V2
  describe Pages::AdditionalPages do
    describe '#build!' do
      let(:supplemental_claim) { create(:extra_supplemental_claim) }

      it 'returns the same object that it received' do
        pdf = Prawn::Document.new

        resulted_pdf = described_class.new(pdf, FormData.new(supplemental_claim)).build!

        expect(resulted_pdf).to eq pdf
      end

      it 'starts a new pdf page' do
        pdf = Prawn::Document.new

        expect { described_class.new(pdf, FormData.new(supplemental_claim)).build! }
          .to change { pdf.page_count }.by 1
      end
    end
  end
end
