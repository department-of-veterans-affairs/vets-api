# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA5490 do
  context 'method tests' do
    let(:education_benefits_claim) { create(:va5490).education_benefits_claim }

    subject do
      education_benefits_claim.instance_variable_set(:@application, nil)
      education_benefits_claim.saved_claim.instance_variable_set(:@application, nil)
      described_class.new(education_benefits_claim)
    end

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
          # rubocop:disable LineLength
          expect(subject.previous_benefits).to eq("DISABILITY COMPENSATION OR PENSION\nDEPENDENTS' INDEMNITY COMPENSATION\nVOCATIONAL REHABILITATION BENEFITS (Chapter 31)\nVETERANS EDUCATION ASSISTANCE BASED ON SOMEONE ELSE'S SERVICE: CHAPTER 35 - SURVIVORS' AND DEPENDENTS' EDUCATIONAL ASSISTANCE PROGRAM (DEA)\nVETERANS EDUCATION ASSISTANCE BASED ON SOMEONE ELSE'S SERVICE: CHAPTER 33 - POST-9/11 GI BILL MARINE GUNNERY SERGEANT DAVID FRY SCHOLARSHIP\nVETERANS EDUCATION ASSISTANCE BASED ON SOMEONE ELSE'S SERVICE: TRANSFERRED ENTITLEMENT\nVETERANS EDUCATION ASSISTANCE BASED ON YOUR OWN SERVICE SPECIFY BENEFIT(S): foo\nOTHER; Specify benefit(s): other")
          # rubocop:enable LineLength
        end

        it 'previously_applied_for_benefits? should return true' do
          expect(subject.previously_applied_for_benefits?).to eq(true)
        end
      end
    end
  end

  %w[kitchen_sink simple].each do |test_application|
    test_spool_file('5490', test_application)
  end
end
