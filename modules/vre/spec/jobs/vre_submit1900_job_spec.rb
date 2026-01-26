# frozen_string_literal: true

require 'rails_helper'

describe VRE::VRESubmit1900Job do
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

  let(:monitor) { double('VRE::VREMonitor') }
  let(:exhaustion_msg) do
    { 'args' => [], 'class' => 'VRE::VRESubmit1900Job', 'error_message' => 'An error occurred',
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

  describe 'when queue is exhausted' do
    before do
      allow(SavedClaim::VeteranReadinessEmploymentClaim).to receive(:find).and_return(claim)
    end

    it 'sends a failure email to user' do
      notification_email = double('notification_email')
      expect(VRE::NotificationEmail).to receive(:new).with(claim.id).and_return(notification_email)
      expect(notification_email).to receive(:deliver).with(:error)

      VRE::VRESubmit1900Job.within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, encrypted_user] }) do
        exhaustion_msg['args'] = [claim.id, encrypted_user]
      end
    end
  end

  describe '#duplicate_submission_check' do
    let(:user_account) { create(:user_account) }
    let(:form_type) { SavedClaim::VeteranReadinessEmploymentClaim::FORM }

    before do
      allow(StatsD).to receive(:increment)
    end

    context 'with nil user_account' do
      it 'returns early without checking duplicates' do
        expect(StatsD).not_to receive(:increment)
        subject.send(:duplicate_submission_check, nil)
      end
    end

    context 'with user_account but no duplicates' do
      it 'does not increment StatsD metric' do
        # Create only 1 submission (not a duplicate)
        create(:form_submission,
               user_account:,
               form_type: SavedClaim::VeteranReadinessEmploymentClaim::FORM,
               created_at: 1.hour.ago)

        subject.send(:duplicate_submission_check, user_account)

        expect(StatsD).not_to have_received(:increment)
      end
    end

    context 'with user_account and duplicate submissions' do
      it 'increments StatsD metric and logs warning' do
        # Create 2 submissions within threshold (duplicate scenario)
        submission1 = create(:form_submission,
                             user_account:,
                             form_type:,
                             created_at: 2.hours.ago)
        submission2 = create(:form_submission,
                             user_account:,
                             form_type:,
                             created_at: 1.hour.ago)

        expect(Rails.logger).to receive(:warn).with(
          'VRE::VRESubmit1900Job - Duplicate Submission Check',
          hash_including(user_account_id: user_account.id, submissions_count: 2, threshold_hours: 24,
                         duplicates_detected: true,
                         submissions_data: [
                           { id: submission1.id, created_at: submission1.created_at },
                           { id: submission2.id, created_at: submission2.created_at }
                         ])
        )

        subject.send(:duplicate_submission_check, user_account)

        expect(StatsD).to have_received(:increment)
          .with('worker.vre.vre_submit_1900_job.duplicate_submission')
      end
    end

    context 'with submissions outside threshold window' do
      it 'does not count old submissions as duplicates' do
        allow(Settings.veteran_readiness_and_employment)
          .to receive(:duplicate_submission_threshold_hours)
          .and_return(24)

        # Create 1 old submission (outside 24hr window) and 1 recent
        create(:form_submission,
               user_account:,
               form_type:,
               created_at: 25.hours.ago)
        create(:form_submission,
               user_account:,
               form_type:,
               created_at: 1.hour.ago)

        subject.send(:duplicate_submission_check, user_account)

        expect(StatsD).not_to have_received(:increment)
      end
    end
  end
end
