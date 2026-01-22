# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsBenefits::SchoolAttendanceApproval do
  before do
    allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
    allow_any_instance_of(DependentsBenefits::SchoolAttendanceApproval).to receive(:pdf_overflow_tracking)
  end

  let(:saved_claim) { create(:student_claim) }

  describe '#to_pdf' do
    it 'does not fail' do
      expect(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_call_original
      expect { saved_claim.to_pdf }.not_to raise_error
    end
  end

  describe '#form_id' do
    it 'returns the correct form id' do
      claim = DependentsBenefits::SchoolAttendanceApproval.new(form: saved_claim.form)
      expect(claim.form_id).to eq('21-674')
    end
  end

  describe '#business_line' do
    it 'returns CMP' do
      claim = DependentsBenefits::SchoolAttendanceApproval.new(form: saved_claim.form)
      expect(claim.business_line).to eq('CMP')
    end
  end
end
