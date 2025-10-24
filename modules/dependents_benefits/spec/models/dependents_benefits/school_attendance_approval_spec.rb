# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsBenefits::SchoolAttendanceApproval do
  before do
    allow_any_instance_of(DependentsBenefits::SchoolAttendanceApproval).to receive(:pdf_overflow_tracking)
  end

  let(:saved_claim) { create(:student_claim) }

  describe '#to_pdf' do
    it 'does not fail' do
      expect(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_call_original
      expect { saved_claim.to_pdf }.not_to raise_error
    end
  end
end
