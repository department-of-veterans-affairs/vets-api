# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::Forms::VA1995 do
  let(:education_benefits_claim) { build(:education_benefits_claim_1995) }

  subject { described_class.new(education_benefits_claim) }

  it 'has a 22-1995 type' do
    expect(described_class::TYPE).to eq('22-1995')
  end

  describe '#text' do
    let(:kitchen_sink) { 'spec/fixtures/education_benefits_claims/1995/kitchen_sink.' }

    before do
      education_benefits_claim.form = File.read("#{kitchen_sink}json")
      education_benefits_claim.save!
      allow(education_benefits_claim).to receive(:id).and_return(1)
    end

    it 'should generate the spool file correctly', run_at: '2017-01-17 03:00:00 -0500' do
      expected_text = File.read("#{kitchen_sink}spl").rstrip
      expected_text.gsub!("\n", EducationForm::WINDOWS_NOTEPAD_LINEBREAK)

      expect(subject.text).to eq(expected_text)
    end
  end
end
