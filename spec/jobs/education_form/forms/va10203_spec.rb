# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA10203 do
  %w[kitchen_sink minimal].each do |test_application|
    test_spool_file('10203', test_application)
  end

  def spool_file_text(file_name)
    windows_linebreak = EducationForm::CreateDailySpoolFiles::WINDOWS_NOTEPAD_LINEBREAK
    expected_text = File.read("spec/fixtures/education_benefits_claims/10203/#{file_name}").rstrip
    expected_text.gsub!("\n", windows_linebreak) unless expected_text.include?(windows_linebreak)
  end

  context 'STEM automated decision' do
    subject { described_class.new(claim) }

    before do
      allow(claim).to receive(:id).and_return(1)
      claim.instance_variable_set(:@application, nil)
      claim.instance_variable_set(:@stem_automated_decision, nil)
    end

    let(:claim) do
      SavedClaim::EducationBenefits::VA10203.create!(
        form: File.read('spec/fixtures/education_benefits_claims/10203/kitchen_sink.json')
      ).education_benefits_claim
    end

    it 'generates the denial spool file with poa', run_at: '2017-01-17 03:00:00 -0500' do
      claim.education_stem_automated_decision = build(:education_stem_automated_decision, :with_poa, :denied)
      expect(subject.text).to eq(spool_file_text('kitchen_sink_stem_ad_with_poa.spl'))
    end

    it 'generates the denial spool file without poa', run_at: '2017-01-17 03:00:00 -0500' do
      claim.education_stem_automated_decision = build(:education_stem_automated_decision, :denied)
      expect(subject.text).to eq(spool_file_text('kitchen_sink_stem_ad_without_poa.spl'))
    end
  end
end
