# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::PdfConstruction::SupplementalClaim::V2::Pages::AdditionalPages do
  describe '#build!' do
    let(:supplemental_claim) { create(:extra_supplemental_claim) }

    it 'returns the same object that it received' do
      pdf = Prawn::Document.new
      form_data = AppealsApi::PdfConstruction::SupplementalClaim::V2::FormData.new(supplemental_claim)

      resulted_pdf = described_class.new(pdf, form_data).build!

      expect(resulted_pdf).to eq pdf
    end

    it 'starts a new pdf page' do
      pdf = Prawn::Document.new
      form_data = AppealsApi::PdfConstruction::SupplementalClaim::V2::FormData.new(supplemental_claim)

      expect { described_class.new(pdf, form_data).build! }
        .to change { pdf.page_count }.by 1
    end
  end
end
