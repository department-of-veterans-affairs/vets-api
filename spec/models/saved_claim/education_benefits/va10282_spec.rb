# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA10282 do
  let(:instance) { build(:va10282) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-10282')

  describe '#after_submit' do
    subject { create(:va10282) }

    let(:user) { create(:user) }

    before do
      allow(VANotify::EmailJob).to receive(:perform_async)
    end

    context 'with the feature enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form22_10282_confirmation_email).and_return(true)
      end

      it 'queues an email job' do
        subject.after_submit(user)
        expect(VANotify::EmailJob).to have_received(:perform_async)
      end
    end

    context 'with the feature disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form22_10282_confirmation_email).and_return(false)
      end

      it 'does nothing' do
        subject.after_submit(user)
        expect(VANotify::EmailJob).not_to have_received(:perform_async)
      end
    end
  end
end
