# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/job_retry'

RSpec.describe BGS::SubmitForm686cV2Job, type: :job do
  let(:job) { subject.perform(user.uuid, dependency_claim.id, encrypted_vet_info) }
  let(:user) { create(:evss_user, :loa3) }
  let(:dependency_claim) { create(:dependency_claim) }
  let(:all_flows_payload) { build(:form_686c_674_kitchen_sink) }
  let(:birth_date) { '1809-02-12' }
  let(:client_stub) { instance_double(BGS::Form686c) }
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
    nested_info = vet_info['veteran_information']
    OpenStruct.new(
      first_name: nested_info['full_name']['first'],
      last_name: nested_info['full_name']['last'],
      middle_name: nested_info['full_name']['middle'],
      ssn: nested_info['ssn'],
      email: nested_info['email'],
      va_profile_email: nested_info['va_profile_email'],
      participant_id: nested_info['participant_id'],
      icn: nested_info['icn'],
      uuid: nested_info['uuid'],
      common_name: nested_info['common_name']
    )
  end
  let(:vanotify) { double(send_email: true) }

  before do
    allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(false)
    allow(OpenStruct).to receive(:new)
      .with(hash_including(icn: vet_info['veteran_information']['icn']))
      .and_return(user_struct)

    allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:pdf_overflow_tracking)
  end

  context 'successfully' do
    it 'calls #submit for 686c submission' do
      expect(BGS::Form686c).to receive(:new).with(user_struct, dependency_claim).and_return(client_stub)
      expect(client_stub).to receive(:submit).once

      expect { job }.not_to raise_error
    end

    it 'sends confirmation email for 686c only' do
      expect(BGS::Form686c).to receive(:new).with(user_struct, dependency_claim).and_return(client_stub)
      expect(client_stub).to receive(:submit).once

      callback_options = {
        callback_klass: 'Dependents::NotificationCallback',
        callback_metadata: { email_template_id: 'fake_received686',
                             email_type: :received686,
                             form_id: '686C-674-V2',
                             claim_id: dependency_claim.id,
                             saved_claim_id: dependency_claim.id,
                             service_name: 'dependents' }
      }

      personalization = { 'confirmation_number' => dependency_claim.confirmation_number,
                          'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                          'first_name' => 'WESLEY' }

      expect(VaNotify::Service).to receive(:new).with('fake_secret', callback_options).and_return(vanotify)
      expect(vanotify).to receive(:send_email).with(
        {
          email_address: user.va_profile_email,
          template_id: 'fake_received686',
          personalisation: personalization
        }.compact
      )

      expect { job }.not_to raise_error
    end

    it 'does not send confirmation email for 686c_674 combo' do
      allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(true)
      expect(BGS::Form686c).to receive(:new).with(user_struct, dependency_claim).and_return(client_stub)
      expect(client_stub).to receive(:submit).once

      expect(VANotify::EmailJob).not_to receive(:perform_async)

      expect { job }.not_to raise_error
    end
  end

  context 'Claim is submittable_674' do
    it 'enqueues SubmitForm674Job' do
      allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(true)
      expect(BGS::Form686c).to receive(:new).with(user_struct, dependency_claim).and_return(client_stub)
      expect(client_stub).to receive(:submit).once
      expect(BGS::SubmitForm674V2Job).to receive(:perform_async).with(user.uuid,
                                                                      dependency_claim.id, encrypted_vet_info,
                                                                      an_instance_of(String))

      expect { job }.not_to raise_error
    end
  end

  context 'Claim is not submittable_674' do
    it 'does not enqueue SubmitForm674Job' do
      expect(BGS::Form686c).to receive(:new).with(user_struct, dependency_claim).and_return(client_stub)
      expect(client_stub).to receive(:submit).once
      expect(BGS::SubmitForm674V2Job).not_to receive(:perform_async)

      expect { job }.not_to raise_error
    end
  end

  context 'when submission raises error' do
    it 'raises error' do
      expect(BGS::Form686c).to receive(:new).with(user_struct, dependency_claim).and_return(client_stub)
      expect(client_stub).to receive(:submit).and_raise(BGS::SubmitForm686cV2Job::Invalid686cClaim)

      expect { job }.to raise_error(BGS::SubmitForm686cV2Job::Invalid686cClaim)
    end

    it 'filters based on error cause' do
      expect(BGS::Form686c).to receive(:new).with(user_struct, dependency_claim).and_return(client_stub)
      expect(client_stub).to receive(:submit) { raise_nested_err }

      expect { job }.to raise_error(Sidekiq::JobRetry::Skip)
    end
  end

  context 'sidekiq_retries_exhausted' do
    it 'tracks exhaustion event and sends backup submission' do
      msg = {
        'args' => [user.uuid, dependency_claim.id, encrypted_vet_info],
        'error_message' => 'Connection timeout'
      }
      error = StandardError.new('Job failed')

      # Mock the monitor
      monitor_double = instance_double(Dependents::Monitor)
      expect(Dependents::Monitor).to receive(:new).with(dependency_claim.id).and_return(monitor_double)

      # Expect the monitor to track the exhaustion event
      expect(monitor_double).to receive(:track_event).with(
        'error',
        'BGS::SubmitForm686cV2Job failed, retries exhausted! Last error: Connection timeout',
        'worker.submit_686c_bgs.exhaustion'
      )

      # Expect the backup submission to be called
      expect(BGS::SubmitForm686cV2Job)
        .to receive(:send_backup_submission)
        .with(vet_info, dependency_claim.id, user.uuid)

      # Call the sidekiq_retries_exhausted callback
      described_class.sidekiq_retries_exhausted_block.call(msg, error)
    end

    it 'monitors errors on retry exhaustion failure' do
      msg = {
        'args' => [user.uuid, dependency_claim.id, encrypted_vet_info],
        'error_message' => 'Connection timeout'
      }
      error = StandardError.new('Job failed')
      # Mock the monitor
      monitor_double = instance_double(Dependents::Monitor)
      allow(Dependents::Monitor).to receive(:new).and_return(monitor_double)

      # Expect the monitor to track the initial exhaustion event
      expect(monitor_double).to receive(:track_event).with(
        'error',
        'BGS::SubmitForm686cV2Job failed, retries exhausted! Last error: Connection timeout',
        'worker.submit_686c_bgs.exhaustion'
      )

      # Mock the backup submission to raise an error
      expect(BGS::SubmitForm686cV2Job).to receive(:send_backup_submission)
        .and_raise(StandardError.new('Retry exhaustion failed'))

      # Expect the monitor to track the retry exhaustion failure event
      expect(monitor_double).to receive(:track_event).with(
        'error',
        'BGS::SubmitForm686cV2Job retries exhausted failed...',
        'worker.submit_686c_bgs.retry_exhaustion_failure',
        hash_including(
          error: 'Retry exhaustion failed',
          nested_error: nil,
          last_error: 'Connection timeout'
        )
      )

      # Call the sidekiq_retries_exhausted callback
      described_class.sidekiq_retries_exhausted_block.call(msg, error)
    end

    context 'when backup submission fails' do
      let(:msg) do
        {
          'args' => [user.uuid, dependency_claim.id, encrypted_vet_info],
          'error_message' => 'Connection timeout'
        }
      end
      let(:error) { StandardError.new('Job failed') }

      before do
        # Mock initial monitor for exhaustion tracking
        monitor_double = instance_double(Dependents::Monitor)
        allow(Dependents::Monitor).to receive(:new).and_return(monitor_double)
        allow(monitor_double).to receive(:track_event)

        # Mock backup submission failure
        allow(BGS::SubmitForm686cV2Job).to receive(:send_backup_submission)
          .and_raise(StandardError.new('Backup failed'))
      end

      context 'when email is present' do
        it 'sends failure email to veteran' do
          # Mock the claim and monitor for the rescue block
          claim_double = instance_double(SavedClaim::DependencyClaim)
          monitor_double = instance_double(Dependents::Monitor)

          expect(SavedClaim::DependencyClaim).to receive(:find).with(dependency_claim.id).and_return(claim_double)
          expect(Dependents::Monitor).to receive(:new).with(no_args).and_return(monitor_double)

          # Expect monitor to track the retry exhaustion failure
          expect(monitor_double).to receive(:track_event).with(
            'error',
            'BGS::SubmitForm686cV2Job retries exhausted failed...',
            'worker.submit_686c_bgs.retry_exhaustion_failure',
            hash_including(error: 'Backup failed')
          )

          # Expect failure email to be sent since email is present
          expect(claim_double).to receive(:send_failure_email).with(user.va_profile_email)

          # Call the sidekiq_retries_exhausted callback
          described_class.sidekiq_retries_exhausted_block.call(msg, error)
        end
      end

      context 'when email is not present' do
        let(:vet_info_no_email) do
          vet_info_copy = vet_info.deep_dup
          vet_info_copy['veteran_information']['va_profile_email'] = nil
          vet_info_copy
        end
        let(:encrypted_vet_info_no_email) { KmsEncrypted::Box.new.encrypt(vet_info_no_email.to_json) }
        let(:msg_no_email) do
          {
            'args' => [user.uuid, dependency_claim.id, encrypted_vet_info_no_email],
            'error_message' => 'Connection timeout'
          }
        end

        it 'logs silent failure when email is not present' do
          # Mock the claim and monitor for the rescue block
          claim_double = instance_double(SavedClaim::DependencyClaim)
          monitor_double = instance_double(Dependents::Monitor)

          expect(SavedClaim::DependencyClaim).to receive(:find).with(dependency_claim.id).and_return(claim_double)
          expect(Dependents::Monitor).to receive(:new).with(no_args).and_return(monitor_double)
          allow(monitor_double).to receive(:default_payload).and_return({})

          # Expect monitor to track the retry exhaustion failure
          expect(monitor_double).to receive(:track_event).with(
            'error',
            'BGS::SubmitForm686cV2Job retries exhausted failed...',
            'worker.submit_686c_bgs.retry_exhaustion_failure',
            hash_including(error: 'Backup failed')
          )

          # Expect silent failure logging when email is not present
          expect(monitor_double).to receive(:log_silent_failure).with(
            hash_including(error: kind_of(StandardError)),
            hash_including(call_location: kind_of(Thread::Backtrace::Location))
          )

          # Should not send failure email
          expect(claim_double).not_to receive(:send_failure_email)

          # Call the sidekiq_retries_exhausted callback
          described_class.sidekiq_retries_exhausted_block.call(msg_no_email, error)
        end
      end
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
        'BGS::SubmitForm686cV2Job backup submission failed...',
        'worker.submit_686c_bgs.backup_failure',
        hash_including(error: 'Backup submission failed')
      )

      # Expect the in-progress form to be marked as submission pending
      expect_any_instance_of(InProgressForm).to receive(:submission_pending!)

      # Call the send_backup_submission method
      expect do
        described_class.send_backup_submission(
          vet_info,
          dependency_claim.id,
          user.uuid
        )
      end.not_to raise_error
    end
  end
end

def raise_nested_err
  raise BGS::SubmitForm686cV2Job::Invalid686cClaim, 'A very specific error occurred: insertBenefitClaim: Invalid zipcode.' # rubocop:disable Layout/LineLength
rescue
  raise BGS::SubmitForm686cV2Job::Invalid686cClaim, 'A Generic Error Occurred'
end
