# frozen_string_literal: true

require 'rails_helper'

module AppealsApi::PdfConstruction::HigherLevelReview::V2
  describe Pages::AdditionalIssues do
    describe '#build!' do
      let(:higher_level_review) { create(:higher_level_review) }

      it 'returns the same object that it received' do
        pdf = Prawn::Document.new

        resulted_pdf = described_class.new(pdf, FormData.new(higher_level_review)).build!

        expect(resulted_pdf).to eq(pdf)
      end

      it 'starts a new pdf page' do
        stub_const(
          'AppealsApi::PdfConstruction::HigherLevelReview::V2::Structure::MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM',
          5
        )

        pdf = Prawn::Document.new

        expect { described_class.new(pdf, FormData.new(higher_level_review)).build! }
          .to change { pdf.page_count }.by(1)
      end
    end
  end
end
