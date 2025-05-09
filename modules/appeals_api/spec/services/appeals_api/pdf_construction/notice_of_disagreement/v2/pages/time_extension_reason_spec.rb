# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::PdfConstruction::NoticeOfDisagreement::V2::Pages::TimeExtensionReason do
  describe '#build!' do
    let(:notice_of_disagreement) { create(:extra_notice_of_disagreement_v2) }

    it 'returns the same object that it received' do
      pdf = Prawn::Document.new
      form_data = AppealsApi::PdfConstruction::NoticeOfDisagreement::V2::FormData.new(notice_of_disagreement)

      resulted_pdf = described_class.new(pdf, form_data).build!

      expect(resulted_pdf).to eq pdf
    end

    it 'starts a new pdf page' do
      pdf = Prawn::Document.new
      form_data = AppealsApi::PdfConstruction::NoticeOfDisagreement::V2::FormData.new(notice_of_disagreement)

      expect { described_class.new(pdf, form_data).build! }
        .to change { pdf.page_count }.by 1
    end
  end
end
