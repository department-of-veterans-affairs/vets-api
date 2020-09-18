# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim do
  let(:saved_claim) { create(:pension_claim) }

  describe '#to_pdf' do
    it 'converts form to pdf' do
      file_path = 'file_path'

      expect(PdfFill::Filler).to receive(:fill_form).with(saved_claim, nil).once.and_return(file_path)
      saved_claim.to_pdf
    end
  end
end
