# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA5490 do
  context 'method tests' do
    subject do
      education_benefits_claim.instance_variable_set(:@application, nil)
      education_benefits_claim.saved_claim.instance_variable_set(:@application, nil)
      described_class.new(education_benefits_claim)
    end

    let(:education_benefits_claim) { create(:va5490).education_benefits_claim }

    before do
      allow_any_instance_of(described_class).to receive(:format)
    end

    describe 'previous benefits' do
      context 'without previous benefits' do
        before do
          education_benefits_claim.saved_claim.form = {
            privacyAgreementAccepted: true,
            previousBenefits: {
              disability: false,
              dic: false,
              chapter31: false,
              ownServiceBenefits: '',
              chapter35: false,
              chapter33: false,
              transferOfEntitlement: false,
              other: ''
            }
          }.to_json
        end

        it 'previously_applied_for_benefits? should return false' do
          expect(subject.previously_applied_for_benefits?).to eq(false)
        end
      end

      context 'with previous benefits' do
        before do
          education_benefits_claim.saved_claim.form = {
            privacyAgreementAccepted: true,
            previousBenefits: {
              disability: true,
              dic: true,
              chapter31: true,
              ownServiceBenefits: 'foo',
              chapter35: true,
              chapter33: true,
              transferOfEntitlement: true,
              other: 'other'
            }
          }.to_json
        end

        it 'previous_benefits should return the right value' do
          # rubocop:disable Layout/LineLength
          expect(subject.previous_benefits).to eq("DISABILITY COMPENSATION OR PENSION\nDEPENDENTS' INDEMNITY COMPENSATION\nVOCATIONAL REHABILITATION BENEFITS (Chapter 31)\nVETERANS EDUCATION ASSISTANCE BASED ON SOMEONE ELSE'S SERVICE: CHAPTER 35 - SURVIVORS' AND DEPENDENTS' EDUCATIONAL ASSISTANCE PROGRAM (DEA)\nVETERANS EDUCATION ASSISTANCE BASED ON SOMEONE ELSE'S SERVICE: CHAPTER 33 - POST-9/11 GI BILL MARINE GUNNERY SERGEANT DAVID FRY SCHOLARSHIP\nVETERANS EDUCATION ASSISTANCE BASED ON SOMEONE ELSE'S SERVICE: TRANSFERRED ENTITLEMENT\nVETERANS EDUCATION ASSISTANCE BASED ON YOUR OWN SERVICE SPECIFY BENEFIT(S): foo\nOTHER; Specify benefit(s): other")
          # rubocop:enable Layout/LineLength
        end

        it 'previously_applied_for_benefits? should return true' do
          expect(subject.previously_applied_for_benefits?).to eq(true)
        end
      end
    end
  end

  context 'spool_file tests' do
    %w[
      simple_chapter_33_biological_child
      simple_chapter_33_step_child
      kitchen_sink_chapter_33_spouse
      kitchen_sink_chapter_35_spouse
      kitchen_sink_chapter_35_adopted_child
    ].each do |test_application|
      test_spool_file('5490', test_application)
    end
  end

  context 'spool_file tests with pow/mia labels' do
    %w[
      kitchen_sink_chapter_33_died_on_duty
      kitchen_sink_chapter_33_died_non_duty
      kitchen_sink_chapter_33_pow_or_mia
    ].each do |test_application|
      test_spool_file('5490', test_application)
    end
  end

  context 'spool_file tests with guardian' do
    %w[
      kitchen_sink_chapter_33_died_non_duty_guardian_graduated
      kitchen_sink_chapter_33_died_non_duty_guardian_not_graduated
    ].each do |test_application|
      test_spool_file('5490', test_application)
    end
  end
end
