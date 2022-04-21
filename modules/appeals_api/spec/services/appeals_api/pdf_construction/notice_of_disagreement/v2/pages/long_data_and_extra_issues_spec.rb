# frozen_string_literal: true

require 'rails_helper'

module AppealsApi::PdfConstruction::NoticeOfDisagreement::V2
  describe Pages::LongDataAndExtraIssues do
    describe '#build!' do
      let(:notice_of_disagreement) { create(:extra_notice_of_disagreement_v2) }

      it 'returns the same object that it received' do
        pdf = Prawn::Document.new
        resulted_pdf = described_class.new(pdf, FormData.new(notice_of_disagreement)).build!

        expect(resulted_pdf).to eq pdf
      end

      it 'starts a new pdf page' do
        pdf = Prawn::Document.new

        expect { described_class.new(pdf, FormData.new(notice_of_disagreement)).build! }
          .to change { pdf.page_count }.by 1
      end
    end
  end
end
