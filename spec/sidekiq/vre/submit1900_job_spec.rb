# frozen_string_literal: true

require 'rails_helper'
require 'vre/notification_email'
require 'vre/notification_callback'
require 'vre/vre_monitor'

describe VRE::Submit1900Job do
  let(:user_struct) do
    OpenStruct.new(
      edipi: '1007697216',
      birls_id: '796043735',
      participant_id: '600061742',
      pid: '600061742',
      birth_date: '1986-05-06T00:00:00+00:00'.to_date,
      ssn: '796043735',
      vet360_id: '1781151',
      loa3?: true,
      icn: '1013032368V065534',
      uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef',
      va_profile_email: 'test@test.com'
    )
  end
  let(:encrypted_user) { KmsEncrypted::Box.new.encrypt(user_struct.to_h.to_json) }
  let(:user) { OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user))) }

  let(:monitor) { double('monitor') }
  let(:exhaustion_msg) do
    { 'args' => [], 'class' => 'VRE::Submit1900Job', 'error_message' => 'An error occurred',
      'queue' => 'default' }
  end
  let(:claim) { create(:veteran_readiness_employment_claim) }

  describe '#perform' do
    subject { described_class.new.perform(claim.id, encrypted_user) }

    before do
      allow(SavedClaim::VeteranReadinessEmploymentClaim).to receive(:find).and_return(claim)
    end

    after do
      subject
    end

    it 'calls claim.add_claimant_info' do
      allow(claim).to receive(:send_to_lighthouse!)
      allow(claim).to receive(:send_to_res)

      expect(claim).to receive(:add_claimant_info).with(user)
    end

    it 'calls claim.send_to_vre' do
      expect(claim).to receive(:send_to_vre).with(user)
    end
  end

  describe 'queue exhaustion' do
    before do
      allow(SavedClaim::VeteranReadinessEmploymentClaim).to receive(:find).and_return(claim)
    end

    describe 'with feature toggle vre_use_new_vfs_notification_library enabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:vre_use_new_vfs_notification_library).and_return(true)
      end

      it 'sends a failure email when retries are exhausted' do
        notification_email = double('notification_email')
        expect(VRE::NotificationEmail).to receive(:new).with(claim.id).and_return(notification_email)
        expect(notification_email).to receive(:deliver).with(:error)

        VRE::Submit1900Job.within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, encrypted_user] }) do
          exhaustion_msg['args'] = [claim.id, encrypted_user]
        end
      end
    end

    describe 'with feature toggle disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:vre_use_new_vfs_notification_library).and_return(false)
        allow(VRE::Monitor).to receive(:new).and_return(monitor)
        allow(monitor).to receive :track_submission_exhaustion
      end

      it 'sends a failure email' do
        VRE::Submit1900Job.within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, encrypted_user] }) do
          exhaustion_msg['args'] = [claim.id, encrypted_user]
          expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim.email)
          expect(VANotify::EmailJob).to receive(:perform_async).with(
            'email@test.com',
            'form1900_action_needed_email_template_id',
            {
              'first_name' => 'First',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => claim.confirmation_number
            }
          )
        end
      end
    end
  end
end
