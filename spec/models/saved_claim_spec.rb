# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim do
  let(:saved_claim) { create(:pension_claim) }

  describe '#to_pdf' do
    it 'should convert form to pdf' do
      file_path = 'file_path'

      expect(PdfFill::Filler).to receive(:fill_form).with(saved_claim).once.and_return(file_path)
      expect(File).to receive(:open).with(file_path).once
      saved_claim.to_pdf
    end
  end
end
