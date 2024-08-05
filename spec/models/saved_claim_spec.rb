# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim do
  let(:saved_claim) { create(:pension_claim) }
  let(:vre_claim) { create(:veteran_readiness_employment_claim) }
  let(:disability_claim) { create(:va526ez) }

  describe '#to_pdf' do
    it 'converts form to pdf' do
      file_path = 'file_path'

      expect(PdfFill::Filler).to receive(:fill_form).with(saved_claim, nil).once.and_return(file_path)
      saved_claim.to_pdf
    end
  end

  describe '#form_matches_schema' do
    it 'is thread-safe' do
      threads = []
      5.times do
        threads << Thread.new do
          disability_claim.form_matches_schema
        end
      end
      5.times do
        threads << Thread.new do
          vre_claim.form_matches_schema
        end
      end
      threads.each(&:join)
    end
  end
end
