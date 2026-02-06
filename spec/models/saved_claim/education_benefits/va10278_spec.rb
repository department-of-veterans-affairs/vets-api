# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA10278 do
  let(:instance) { build(:va10278) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-10278')

  describe '#business_line' do
    it 'returns EDU' do
      expect(instance.business_line).to eq('EDU')
    end
  end

  describe '#after_submit' do
    let(:claim) { create(:va10278) }
    let(:user) { create(:user) }

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form22_10278_benefits_intake_submission).and_return(true)
      end

      it 'enqueues the Submit10278Job' do
        expect(EducationForm::BenefitsIntake::Submit10278Job).to receive(:perform_async)
          .with(claim.id, user.user_account_uuid)
        claim.after_submit(user)
      end

      context 'when user is nil' do
        it 'enqueues the job with nil user_account_uuid' do
          expect(EducationForm::BenefitsIntake::Submit10278Job).to receive(:perform_async)
            .with(claim.id, nil)
          claim.after_submit(nil)
        end
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form22_10278_benefits_intake_submission).and_return(false)
      end

      it 'does not enqueue any job' do
        expect(EducationForm::BenefitsIntake::Submit10278Job).not_to receive(:perform_async)
        claim.after_submit(user)
      end
    end
  end
end
