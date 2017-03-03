# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::Forms::VA5490 do
  let(:education_benefits_claim) { build(:education_benefits_claim_5490) }

  subject { described_class.new(education_benefits_claim) }

  before do
    allow_any_instance_of(described_class).to receive(:format)
  end

  describe '#previously_applied_for_benefits?' do
    context 'without previous benefits' do
      before do
        education_benefits_claim.form = {
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

      it 'should return false' do
        expect(subject.previously_applied_for_benefits?).to eq(false)
      end
    end

    context 'with previous benefits' do
      before do
        education_benefits_claim.form = {
          privacyAgreementAccepted: true,
          previousBenefits: {
            disability: false,
            dic: false,
            chapter31: false,
            ownServiceBenefits: 'foo',
            chapter35: false,
            chapter33: false,
            transferOfEntitlement: false,
            other: ''
          }
        }.to_json
      end

      it 'should return true' do
        expect(subject.previously_applied_for_benefits?).to eq(true)
      end
    end
  end
end
