# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require_relative '../../spec_helper'

Sidekiq::Testing.fake!

# rubocop:disable Metrics/ModuleLength
module AccreditedRepresentativePortal
  RSpec.describe RedactPowerOfAttorneyRequestsJob, type: :job do
    # Helper to add redactable data to a submission
    def add_redactable_submission_data(submission)
      # Disable validation skip check: Directly setting ciphertext for test setup.
      # rubocop:disable Rails/SkipsModelValidations
      submission&.update_columns(
        service_response_ciphertext: 'some_encrypted_response',
        error_message_ciphertext: nil
      )
      # rubocop:enable Rails/SkipsModelValidations
    end

    # Helper to add redactable data to a resolution
    def add_redactable_resolution_data(resolution)
      # Disable validation skip check: Directly setting ciphertext for test setup.
      # rubocop:disable Rails/SkipsModelValidations
      resolution&.update_column(:reason_ciphertext, 'some_encrypted_reason')
      # rubocop:enable Rails/SkipsModelValidations
    end

    # Helper to explicitly nullify redactable data
    def ensure_no_redactable_data(request)
      # Disable validation skip check: Directly setting state for test setup.
      # rubocop:disable Rails/SkipsModelValidations
      request.power_of_attorney_form_submission&.update_columns(
        service_response_ciphertext: nil,
        error_message_ciphertext: nil
      )
      request.resolution&.update_column(:reason_ciphertext, nil)
      # rubocop:enable Rails/SkipsModelValidations
      request # return request for chaining if needed
    end

    describe '#perform' do
      let(:job) { described_class.new }

      # --- Setup various Power of Attorney request states ---
      let!(:expired_request_with_data) do
        create(:power_of_attorney_request, :with_expiration,
               :with_form_submission).tap do |r|
          add_redactable_submission_data(r.power_of_attorney_form_submission)
        end
      end
      let!(:stale_request_with_data) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission,
               resolution_created_at: 61.days.ago).tap do |r|
          add_redactable_resolution_data(r.resolution)
        end
      end
      # This request is now eligible for redaction attempt because the data check was removed
      let!(:expired_request_no_data) do
        create(:power_of_attorney_request, :with_expiration,
               :with_form_submission).tap do |r|
          ensure_no_redactable_data(r)
        end
      end
      # This request is now eligible for redaction attempt because the data check was removed
      let!(:stale_request_no_data) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission,
               resolution_created_at: 61.days.ago).tap do |r|
          ensure_no_redactable_data(r)
        end
      end
      let!(:recent_request) do
        create(:power_of_attorney_request, :with_declination, :with_form_submission, resolution_created_at: 1.day.ago)
      end
      let!(:unresolved_request) { create(:power_of_attorney_request) }
      let!(:stale_but_redacted_request) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission,
               resolution_created_at: 61.days.ago, redacted_at: 1.day.ago).tap do |r|
          add_redactable_resolution_data(r.resolution)
        end
      end

      it 'logs the start and end of the job' do
        allow(Rails.logger).to receive(:info).with(a_string_matching(/Redacting PowerOfAttorneyRequest/))
        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:info).with(a_string_matching(/Starting job/)).ordered
        expect(Rails.logger).to receive(:info).with(a_string_matching(/Finished job/)).ordered
        job.perform
      end

      # Updated to reflect that requests without data are now also redacted
      it 'redacts eligible requests and logs the results' do
        allow(Rails.logger).to receive(:info).with(a_string_matching(/Redacting PowerOfAttorneyRequest/))
        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:info).with(a_string_matching(/Starting job/)).ordered
        # Updated log count from 2 to 4
        log_matcher = a_string_matching(/Finished job. Redacted 4 requests. Encountered 0 errors./)
        expect(Rails.logger).to receive(:info).with(log_matcher).ordered

        job.perform

        # ----- Verification of Side Effects -----
        expect(expired_request_with_data.reload.redacted_at).to be_present
        expect(stale_request_with_data.reload.redacted_at).to be_present
        # These two are now redacted because the data check was removed from ID fetching
        expect(expired_request_no_data.reload.redacted_at).to be_present
        expect(stale_request_no_data.reload.redacted_at).to be_present
        # These remain unchanged
        expect(recent_request.reload.redacted_at).to be_nil
        expect(unresolved_request.reload.redacted_at).to be_nil
        original_redacted_timestamp = stale_but_redacted_request.redacted_at
        expect(stale_but_redacted_request.reload.redacted_at).to eq(original_redacted_timestamp)
      end

      # Updated to reflect that requests without data are now also attempted
      it 'calls #attempt_redaction for all eligible requests (regardless of data presence)' do
        attempted_requests = []
        original_method = job.method(:attempt_redaction)

        allow(job).to receive(:attempt_redaction) do |request_arg|
          attempted_requests << request_arg
          # IMPORTANT: Call the *original* method implementation manually
          # using the stored reference to ensure the actual job logic runs.
          original_method.call(request_arg)
        end

        job.perform

        attempted_request_ids = attempted_requests.map(&:id)

        # Now includes requests without data that meet the time/status criteria
        expect(attempted_request_ids).to contain_exactly(
          expired_request_with_data.id,
          stale_request_with_data.id,
          expired_request_no_data.id,
          stale_request_no_data.id
        )
      end
    end

    describe '#eligible_requests_for_redaction' do
      let(:job) { described_class.new }
      let!(:expired_request_with_data) do
        create(:power_of_attorney_request, :with_expiration,
               :with_form_submission).tap do |r|
          add_redactable_submission_data(r.power_of_attorney_form_submission)
        end
      end
      let!(:stale_request_with_data) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission,
               resolution_created_at: 61.days.ago).tap do |r|
          add_redactable_resolution_data(r.resolution)
        end
      end
      # This request is now eligible because the data check was removed from ID fetching
      let!(:expired_request_no_data) do
        create(:power_of_attorney_request, :with_expiration,
               :with_form_submission).tap do |r|
          ensure_no_redactable_data(r)
        end
      end
      # This request is now eligible because the data check was removed from ID fetching
      let!(:stale_request_no_data) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission,
               resolution_created_at: 61.days.ago).tap do |r|
          ensure_no_redactable_data(r)
        end
      end
      let!(:recent_request) do
        create(:power_of_attorney_request, :with_declination, :with_form_submission, resolution_created_at: 1.day.ago)
      end
      let!(:unresolved_request) { create(:power_of_attorney_request) }
      let!(:stale_but_redacted_request) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission,
               resolution_created_at: 61.days.ago, redacted_at: 1.day.ago).tap do |r|
          add_redactable_resolution_data(r.resolution)
        end
      end

      # Updated description and expectations
      it 'returns requests meeting criteria (expired/stale, unredacted), regardless of redactable data' do
        eligible_requests = job.send(:eligible_requests_for_redaction)
        # Now includes the requests without specific data fields populated
        expect(eligible_requests).to contain_exactly(
          expired_request_with_data,
          stale_request_with_data,
          expired_request_no_data,
          stale_request_no_data
        )
        expect(eligible_requests.size).to eq(4)
        expect(eligible_requests).not_to include(
          recent_request,
          unresolved_request,
          stale_but_redacted_request
        )
      end
    end

    describe '#expired_request_ids' do
      let(:job) { described_class.new }
      let!(:expired_request_with_data) do
        create(:power_of_attorney_request, :with_expiration,
               :with_form_submission).tap do |r|
          add_redactable_resolution_data(r.resolution) # Add some data
        end
      end
      # This request is now included because the data check was removed
      let!(:expired_request_no_data) do
        create(:power_of_attorney_request, :with_expiration,
               :with_form_submission).tap do |r|
          ensure_no_redactable_data(r) # Ensure no specific data
        end
      end
      let!(:expired_no_submission) { create(:power_of_attorney_request, :with_expiration) }
      let!(:accepted_request) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission).tap do |r|
          add_redactable_resolution_data(r.resolution)
        end
      end
      let!(:redacted_expired_request) do
        create(:power_of_attorney_request, :with_expiration, :with_form_submission,
               redacted_at: 1.day.ago).tap do |r|
          add_redactable_resolution_data(r.resolution)
        end
      end

      # Updated description and expectations
      it 'returns the ids of unredacted, expired requests (regardless of redactable data)' do
        expect(job.send(:expired_request_ids)).to contain_exactly(
          expired_request_with_data.id,
          expired_request_no_data.id
        )
      end
    end

    describe '#stale_processed_request_ids' do
      let(:job) { described_class.new }
      let!(:stale_accepted_with_data) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission,
               resolution_created_at: 61.days.ago).tap do |r|
          add_redactable_submission_data(r.power_of_attorney_form_submission) # Add some data
        end
      end
      let!(:stale_declined_with_data) do
        create(:power_of_attorney_request, :with_declination, :with_form_submission,
               resolution_created_at: 61.days.ago).tap do |r|
          add_redactable_resolution_data(r.resolution) # Add some data
        end
      end
      # This request is now included because the data check was removed
      let!(:stale_accepted_no_data) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission,
               resolution_created_at: 61.days.ago).tap do |r|
          ensure_no_redactable_data(r) # Ensure no specific data
        end
      end
      let!(:recent_accepted_request) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission,
               resolution_created_at: 1.day.ago).tap do |r|
          add_redactable_submission_data(r.power_of_attorney_form_submission)
        end
      end
      let!(:stale_expired_request) do
        create(:power_of_attorney_request, :with_expiration, :with_form_submission,
               resolution_created_at: 61.days.ago).tap do |r|
          add_redactable_submission_data(r.power_of_attorney_form_submission)
        end
      end
      let!(:stale_unresolved_request) { create(:power_of_attorney_request, created_at: 61.days.ago) }
      let!(:stale_redacted_request) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission,
               resolution_created_at: 61.days.ago, redacted_at: 1.day.ago).tap do |r|
          add_redactable_submission_data(r.power_of_attorney_form_submission)
        end
      end

      # Updated description and expectations
      it 'returns the ids of stale, processed (non-expired), unredacted requests (regardless of redactable data)' do
        # Now includes stale_accepted_no_data.id
        expect(job.send(:stale_processed_request_ids)).to contain_exactly(
          stale_accepted_with_data.id,
          stale_declined_with_data.id,
          stale_accepted_no_data.id
        )
      end
    end

    # No changes needed for the following contexts as they test behavior downstream
    # of the ID fetching, and that downstream behavior (redaction attempt, logging)
    # hasn't fundamentally changed its process, only the scope of inputs it receives.

    describe '#process_requests' do
      let(:job) { described_class.new }
      let(:request1) { build_stubbed(:power_of_attorney_request) }
      let(:request2) { build_stubbed(:power_of_attorney_request) }
      let(:requests) { [request1, request2] }

      it 'attempts to redact each request and returns a count of successes and errors' do
        allow(job).to receive(:attempt_redaction).with(request1).and_return(true)
        allow(job).to receive(:attempt_redaction).with(request2).and_return(false)
        results = job.send(:process_requests, requests)
        expect(results).to eq({ redacted: 1, errors: 1 })
      end
    end

    describe '#attempt_redaction' do
      let(:job) { described_class.new }
      let(:request) { build_stubbed(:power_of_attorney_request) }

      it 'calls #redact_request and returns true on success' do
        expect(job).to receive(:redact_request).with(request)
        expect(job.send(:attempt_redaction, request)).to be(true)
      end

      it 'logs an error and returns false on failure' do
        error = StandardError.new('Redaction failed')
        expect(job).to receive(:redact_request).with(request).and_raise(error)
        expect(job).to receive(:log_redaction_error).with(request, error)
        expect(job.send(:attempt_redaction, request)).to be(false)
      end
    end

    describe '#redact_request' do
      let(:job) { described_class.new }
      # Use let! to ensure associations are created before tests run
      let!(:request) { create(:power_of_attorney_request, :with_declination, :with_form_submission) }
      # Define associations based on the created request
      let!(:form) { request.power_of_attorney_form }
      let!(:submission) { request.power_of_attorney_form_submission }
      let!(:resolution) { request.resolution }

      # Setup: Ensure some data exists to verify nullification
      before do
        # Ensure the associations actually exist before trying to update them
        raise 'Setup error: Submission not created' unless submission
        raise 'Setup error: Resolution not created' unless resolution

        # Disable validation skip check: Directly setting ciphertext for test setup.
        # rubocop:disable Rails/SkipsModelValidations
        resolution.update_column(:reason_ciphertext, 'encrypted_reason')
        submission.update_columns(
          service_response_ciphertext: 'encrypted_response',
          error_message_ciphertext: 'encrypted_error'
        )
        # rubocop:enable Rails/SkipsModelValidations
        request.reload # Ensure changes are reflected if needed later
      end

      it 'redacts the request within a transaction' do
        expect(request).to receive(:transaction).and_call_original
        job.send(:redact_request, request)
        expect(request.reload.redacted_at).to be_present
      end

      it 'logs the request redaction' do
        expect(job).to receive(:log_request_redaction).with(request)
        job.send(:redact_request, request)
      end

      # Test form deletion only if the factory trait reliably creates one
      # No change needed here conceptually
      it 'destroys the associated form if present' do
        if form.present? # Only run expectation if form was created
          expect do
            job.send(:redact_request, request)
          end.to change { AccreditedRepresentativePortal::PowerOfAttorneyForm.exists?(form.id) }.from(true).to(false)
        else
          # If form isn't created by factory, ensure no error is raised
          expect { job.send(:redact_request, request) }.not_to raise_error
          skip("Skipping form destruction check as factory didn't create a form for this request.")
        end
      end

      it 'nullifies submission data' do
        expect(submission).to be_present # Verify setup
        expect(submission.service_response_ciphertext).not_to be_nil # Verify setup

        job.send(:redact_request, request)
        submission.reload

        expect(submission.service_response_ciphertext).to be_nil
        expect(submission.error_message_ciphertext).to be_nil
      end

      it 'nullifies the resolution reason ciphertext' do
        expect(resolution).to be_present # Verify setup
        expect(resolution.reason_ciphertext).not_to be_nil # Verify setup

        job.send(:redact_request, request)
        resolution.reload

        expect(resolution.reason_ciphertext).to be_nil
        expect(resolution.reason).to be_nil
      end

      it 'marks the request as redacted by touching redacted_at' do
        expect do
          job.send(:redact_request, request)
        end.to change { request.reload.redacted_at }.from(nil).to(be_present)
      end

      context 'when form is already destroyed or nil' do
        before do
          request.power_of_attorney_form&.destroy!
          request.reload
        end

        it 'handles missing form without error' do
          expect(request.power_of_attorney_form).to be_nil
          expect { job.send(:redact_request, request) }.not_to raise_error
          expect(request.reload.redacted_at).to be_present
        end
      end

      context 'when submission is nil' do
        before do
          request.power_of_attorney_form_submission&.destroy!
          request.reload
        end

        it 'handles nil submission without error' do
          expect(request.power_of_attorney_form_submission).to be_nil
          expect { job.send(:redact_request, request) }.not_to raise_error
          expect(request.reload.redacted_at).to be_present
        end
      end

      context 'when resolution is nil' do
        before do
          request.resolution&.destroy!
          request.reload
        end

        it 'handles nil resolution without error' do
          expect(request.resolution).to be_nil
          expect { job.send(:redact_request, request) }.not_to raise_error
          expect(request.reload.redacted_at).to be_present
        end
      end

      it 'retains skeleton PowerOfAttorneyRequest fields after redaction' do
        original_claimant_id = request.claimant_id
        original_claimant_type = request.claimant_type
        original_poa_code = request.power_of_attorney_holder_poa_code
        original_poa_type = request.power_of_attorney_holder_type
        original_created_at = request.created_at

        job.send(:redact_request, request)
        request.reload

        expect(request.claimant_id).to eq(original_claimant_id)
        expect(request.claimant_type).to eq(original_claimant_type)
        expect(request.power_of_attorney_holder_poa_code).to eq(original_poa_code)
        expect(request.power_of_attorney_holder_type).to eq(original_poa_type)
        expect(request.created_at).to eq(original_created_at)
        expect(request.redacted_at).to be_present
      end

      it 'retains skeleton Resolution fields (excluding reason ciphertext) after redaction' do
        expect(resolution).to be_present
        original_resolving_type = resolution.resolving_type
        original_resolving_id = resolution.resolving_id
        original_poa_request_id = resolution.power_of_attorney_request_id
        original_created_at = resolution.created_at

        job.send(:redact_request, request)
        resolution.reload

        expect(resolution.resolving_type).to eq(original_resolving_type)
        expect(resolution.resolving_id).to eq(original_resolving_id)
        expect(resolution.power_of_attorney_request_id).to eq(original_poa_request_id)
        expect(resolution.created_at).to eq(original_created_at)
        expect(resolution.reason_ciphertext).to be_nil
        expect(resolution.reason).to be_nil
      end
    end

    describe 'logging methods' do
      let(:job) { described_class.new }
      let(:request_id) { SecureRandom.uuid }
      let(:request) { build_stubbed(:power_of_attorney_request, id: request_id) }
      let(:error) { StandardError.new('Test error') }

      it '#log_start logs the start message' do
        expect(Rails.logger).to receive(:info).with(/Starting job/)
        job.send(:log_start)
      end

      it '#log_request_redaction logs the request redaction' do
        expect(Rails.logger).to receive(:info).with(/Redacting PowerOfAttorneyRequest ##{request.id}/)
        job.send(:log_request_redaction, request)
      end

      it '#log_redaction_error logs the error details' do
        allow(error).to receive(:backtrace).and_return(['line 1', 'line 2'])
        expected_log_message = "#{described_class.name}: Failed to redact PowerOfAttorneyRequest " \
                               "##{request.id}. Error: #{error.message}\nline 1\nline 2"
        expect(Rails.logger).to receive(:error).with(expected_log_message)
        job.send(:log_redaction_error, request, error)
      end

      it '#log_end logs the end message with results' do
        expect(Rails.logger).to receive(:info).with(/Finished job. Redacted 5 requests. Encountered 2 errors./)
        job.send(:log_end, { redacted: 5, errors: 2 })
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
