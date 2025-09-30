# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/job_retry'
require 'dependents/monitor'

RSpec.describe BGS::SubmitForm674V2Job, type: :job do
  # Performance tweak
  before { allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:pdf_overflow_tracking) }

  let(:user) { create(:evss_user, :loa3, :with_terms_of_use_agreement) }
  let(:dependency_claim) { create(:dependency_claim) }
  let(:dependency_claim_674_only) { create(:dependency_claim_674_only) }
  let(:all_flows_payload) { build(:form_686c_674_kitchen_sink) }
  let(:birth_date) { '1809-02-12' }
  let(:client_stub) { instance_double(BGSV2::Form674) }
  let(:vet_info) do
    {
      'veteran_information' => {
        'full_name' => {
          'first' => 'WESLEY', 'middle' => nil, 'last' => 'FORD'
        },
        'common_name' => user.common_name,
        'participant_id' => '600061742',
        'uuid' => user.uuid,
        'email' => user.email,
        'va_profile_email' => user.va_profile_email,
        'ssn' => '796043735',
        'va_file_number' => '796043735',
        'icn' => user.icn,
        'birth_date' => birth_date
      }
    }
  end
  let(:encrypted_vet_info) { KmsEncrypted::Box.new.encrypt(vet_info.to_json) }
  let(:user_struct) do
    OpenStruct.new(
      first_name: vet_info['veteran_information']['full_name']['first'],
      last_name: vet_info['veteran_information']['full_name']['last'],
      middle_name: vet_info['veteran_information']['full_name']['middle'],
      ssn: vet_info['veteran_information']['ssn'],
      email: vet_info['veteran_information']['email'],
      va_profile_email: vet_info['veteran_information']['va_profile_email'],
      participant_id: vet_info['veteran_information']['participant_id'],
      icn: vet_info['veteran_information']['icn'],
      uuid: vet_info['veteran_information']['uuid'],
      common_name: vet_info['veteran_information']['common_name']
    )
  end
  let(:encrypted_user_struct) { KmsEncrypted::Box.new.encrypt(user_struct.to_h.to_json) }

  context 'success' do
    before do
      expect(BGSV2::Form674).to receive(:new).with(user_struct, dependency_claim).and_return(client_stub)
      expect(client_stub).to receive(:submit).once
    end

    it 'successfully calls #submit for 674 submission' do
      expect(OpenStruct).to receive(:new)
        .with(hash_including(user_struct.to_h.stringify_keys))
        .and_return(user_struct)
      expect do
        subject.perform(user.uuid, dependency_claim.id, encrypted_vet_info, encrypted_user_struct)
      end.not_to raise_error
    end

    it 'successfully calls #submit without a user_struct passed in by 686c' do
      expect(OpenStruct).to receive(:new)
        .with(hash_including(icn: vet_info['veteran_information']['icn']))
        .and_return(user_struct)
      expect do
        subject.perform(user.uuid, dependency_claim.id, encrypted_vet_info)
      end.not_to raise_error
    end

    it 'sends confirmation email for combined forms' do
      expect(OpenStruct).to receive(:new)
        .with(hash_including('icn' => vet_info['veteran_information']['icn']))
        .and_return(user_struct)
      expect(VANotify::EmailJob).to receive(:perform_async).with(
        user.va_profile_email,
        'fake_received686c674',
        { 'confirmation_number' => dependency_claim.confirmation_number,
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
          'first_name' => 'WESLEY' },
        'fake_secret',
        { callback_klass: 'Dependents::NotificationCallback',
          callback_metadata: { email_template_id: 'fake_received686c674',
                               email_type: :received686c674,
                               form_id: '686C-674',
                               saved_claim_id: dependency_claim.id,
                               service_name: 'dependents' } }
      )

      subject.perform(user.uuid, dependency_claim.id, encrypted_vet_info, encrypted_user_struct)
    end
  end

  context 'error with central submission' do
    before do
      allow(OpenStruct).to receive(:new).and_call_original
      InProgressForm.create!(form_id: '686C-674', user_uuid: user.uuid, user_account: user.user_account,
                             form_data: all_flows_payload)
    end

    it 'raises error' do
      expect(OpenStruct).to receive(:new)
        .with(hash_including('icn' => vet_info['veteran_information']['icn']))
        .and_return(user_struct)
      expect(BGSV2::Form674).to receive(:new).with(user_struct, dependency_claim) { client_stub }
      expect(client_stub).to receive(:submit).and_raise(BGS::SubmitForm674V2Job::Invalid674Claim)

      expect do
        subject.perform(user.uuid, dependency_claim.id, encrypted_vet_info, encrypted_user_struct)
      end.to raise_error(BGS::SubmitForm674V2Job::Invalid674Claim)
    end

    it 'filters based on error cause' do
      expect(OpenStruct).to receive(:new)
        .with(hash_including('icn' => vet_info['veteran_information']['icn']))
        .and_return(user_struct)
      expect(BGSV2::Form674).to receive(:new).with(user_struct, dependency_claim) { client_stub }
      expect(client_stub).to receive(:submit) { raise_nested_err }

      expect do
        subject.perform(user.uuid, dependency_claim.id, encrypted_vet_info, encrypted_user_struct)
      end.to raise_error(Sidekiq::JobRetry::Skip)
    end
  end

  context '674 only' do
    it 'sends confirmation email for 674 only' do
      expect(BGSV2::Form674).to receive(:new).and_return(client_stub)
      expect(client_stub).to receive(:submit).once
      expect(OpenStruct).to receive(:new)
        .with(hash_including('icn' => vet_info['veteran_information']['icn']))
        .and_return(user_struct)
      expect(VANotify::EmailJob).to receive(:perform_async).with(
        user.va_profile_email,
        'fake_received674',
        { 'confirmation_number' => dependency_claim_674_only.confirmation_number,
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
          'first_name' => 'WESLEY' },
        'fake_secret',
        { callback_klass: 'Dependents::NotificationCallback',
          callback_metadata: { email_template_id: 'fake_received674',
                               email_type: :received674,
                               form_id: '686C-674',
                               saved_claim_id: dependency_claim_674_only.id,
                               service_name: 'dependents' } }
      )

      subject.perform(user.uuid, dependency_claim_674_only.id, encrypted_vet_info, encrypted_user_struct)
    end
  end

  context 'sidekiq_retries_exhausted' do
    it 'tracks exhaustion event and sends backup submission' do
      msg = {
        'args' => [user.uuid, dependency_claim.id, encrypted_vet_info, encrypted_user_struct],
        'error_message' => 'Connection timeout'
      }
      error = StandardError.new('Job failed')

      # Mock the monitor
      monitor_double = instance_double(Dependents::Monitor)
      expect(Dependents::Monitor).to receive(:new).with(dependency_claim.id).and_return(monitor_double)

      # Expect the monitor to track the exhaustion event
      expect(monitor_double).to receive(:track_event).with(
        'error',
        'BGS::SubmitForm674Job failed, retries exhausted! Last error: Connection timeout',
        'worker.submit_674_bgs.exhaustion'
      )

      # Expect the backup submission to be called
      expect(BGS::SubmitForm674V2Job).to receive(:send_backup_submission).with(
        encrypted_user_struct,
        vet_info,
        dependency_claim.id,
        user.uuid
      )

      # Call the sidekiq_retries_exhausted callback
      described_class.sidekiq_retries_exhausted_block.call(msg, error)
    end
  end

  context 'send_backup_submission exception' do
    let(:in_progress_form) do
      InProgressForm.create!(
        form_id: '686C-674-V2',
        user_uuid: user.uuid,
        user_account: user.user_account,
        form_data: all_flows_payload
      )
    end

    before do
      allow(OpenStruct).to receive(:new).and_call_original
      in_progress_form
    end

    it 'handles exceptions during backup submission' do
      # Mock the monitor
      monitor_double = instance_double(Dependents::Monitor)
      expect(Dependents::Monitor).to receive(:new).with(dependency_claim.id).and_return(monitor_double)

      # Mock the backup submission to raise an error
      expect(Lighthouse::BenefitsIntake::SubmitCentralForm686cV2Job).to receive(:perform_async)
        .and_raise(StandardError.new('Backup submission failed'))

      # Expect the monitor to track the error event
      expect(monitor_double).to receive(:track_event).with(
        'error',
        'BGS::SubmitForm674Job backup submission failed...',
        'worker.submit_674_bgs.backup_failure',
        hash_including(error: 'Backup submission failed')
      )

      # Expect the in-progress form to be marked as submission pending
      expect_any_instance_of(InProgressForm).to receive(:submission_pending!)

      # Call the send_backup_submission method
      expect do
        described_class.send_backup_submission(
          encrypted_user_struct,
          vet_info,
          dependency_claim.id,
          user.uuid
        )
      end.not_to raise_error
    end
  end
end

def raise_nested_err
  raise BGS::SubmitForm674V2Job::Invalid674Claim, 'A very specific error occurred: insertBenefitClaim: Invalid zipcode.'
rescue
  raise BGS::SubmitForm674V2Job::Invalid674Claim, 'A Generic Error Occurred'
end
