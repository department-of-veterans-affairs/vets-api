# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsBenefits::PrimaryDependencyClaim do
  before do
    allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
    allow_any_instance_of(DependentsBenefits::PrimaryDependencyClaim).to receive(:pdf_overflow_tracking)
  end

  let(:saved_claim) { create(:dependents_claim) }

  describe '#form_id' do
    it 'returns the correct form id' do
      claim = DependentsBenefits::PrimaryDependencyClaim.new(form: saved_claim.form)
      claim.save!
      expect(claim.form_id).to eq('686C-674')
    end
  end
end
