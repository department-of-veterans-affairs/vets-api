# frozen_string_literal: true

require 'rails_helper'

module AppealsApi::PdfConstruction::HigherLevelReview::V1
  describe Pages::AdditionalIssues do
    describe '#build!' do
      let(:higher_level_review) { create(:higher_level_review) }

      it 'returns the same object that it received' do
        pdf = Prawn::Document.new(skip_page_creation: true)

        resulted_pdf = described_class.new(pdf, FormData.new(higher_level_review)).build!

        expect(resulted_pdf).to eq(pdf)
      end

      context 'extra issues' do
        let(:extra_higher_level_review) { create(:extra_higher_level_review) }

        it 'starts a new pdf page' do
          pdf = Prawn::Document.new(skip_page_creation: true)

          expect { described_class.new(pdf, FormData.new(extra_higher_level_review)).build! }
            .to change { pdf.page_count }.by(1)
        end
      end

      context 'no extra issues' do
        let(:minimal_higher_level_review) { create(:minimal_higher_level_review) }

        it 'does not start a new pdf page' do
          pdf = Prawn::Document.new(skip_page_creation: true)

          expect { described_class.new(pdf, FormData.new(minimal_higher_level_review)).build! }
            .not_to change { pdf.page_count }.from(0)
        end
      end
    end
  end
end
