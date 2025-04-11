# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require_relative '../../spec_helper' # Adjust if necessary

Sidekiq::Testing.fake!

# rubocop:disable Metrics/ModuleLength
module AccreditedRepresentativePortal
  RSpec.describe RedactPowerOfAttorneyRequestsJob, type: :job do
    # NOTE: Keep an eye on potential submission data nullification issues;
    # check for callbacks or other logic in the PowerOfAttorneyFormSubmission model
    # if the related test ('nullifies submission data' in #redact_request) fails.

    describe '#perform' do
      let(:job) { described_class.new }

      # Setup various Power of Attorney request states using factories
      let!(:expired_request) do
        # Creates a request resolved by expiration
        create(:power_of_attorney_request, :with_expiration, :with_form_submission)
      end
      let!(:stale_request) do
        # Creates a request resolved by acceptance over 60 days ago
        # Requires :with_form_submission for redaction logic.
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission, resolution_created_at: 61.days.ago)
      end
      let!(:recent_request) do
        # Creates a request resolved recently (declination)
        create(:power_of_attorney_request, :with_declination, :with_form_submission, resolution_created_at: 1.day.ago)
      end
      let!(:unresolved_request) do
        # Creates a request without any resolution
        create(:power_of_attorney_request)
      end
      let!(:stale_but_redacted_request) do
        # Creates a stale request that is already redacted; should not be processed again
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission, resolution_created_at: 61.days.ago,
                                                                                    redacted_at: 1.day.ago)
      end

      it 'logs the start and end of the job' do
        # Allow intervening logs (redaction details, errors) which occur between start/end
        allow(Rails.logger).to receive(:info).with(a_string_matching(/Redacting PowerOfAttorneyRequest/))
        allow(Rails.logger).to receive(:error)

        # Expect start and end logs in order relative to each other
        expect(Rails.logger).to receive(:info).with(a_string_matching(/Starting job/)).ordered
        expect(Rails.logger).to receive(:info).with(a_string_matching(/Finished job/)).ordered

        job.perform
      end

      it 'redacts only eligible (expired or stale processed unredacted) requests and logs the results' do
        # Allow intervening logs (redaction details, errors)
        allow(Rails.logger).to receive(:info).with(a_string_matching(/Redacting PowerOfAttorneyRequest/))
        allow(Rails.logger).to receive(:error)

        # Expect start log, then the final summary log, in order.
        expect(Rails.logger).to receive(:info).with(a_string_matching(/Starting job/)).ordered
        # Expect the summary log for the 2 eligible requests based on the setup above
        expect(Rails.logger).to receive(:info).with(a_string_matching(/Redacted 2 requests/)).ordered

        job.perform

        # ----- Verification of Side Effects -----

        # These should have been redacted
        expect(expired_request.reload.redacted_at).to be_present
        expect(stale_request.reload.redacted_at).to be_present

        # These should NOT have been redacted
        expect(recent_request.reload.redacted_at).to be_nil # Still recent
        expect(unresolved_request.reload.redacted_at).to be_nil # Unresolved

        # This was already redacted and should NOT have been touched again
        original_redacted_timestamp = stale_but_redacted_request.redacted_at
        expect(stale_but_redacted_request.reload.redacted_at).to eq(original_redacted_timestamp)
      end

      it 'calls #attempt_redaction for each eligible request' do
        # Spy on attempt_redaction to ensure it's called only for the correct requests
        expect(job).to receive(:attempt_redaction).with(expired_request).and_call_original
        expect(job).to receive(:attempt_redaction).with(stale_request).and_call_original
        expect(job).not_to receive(:attempt_redaction).with(recent_request)
        expect(job).not_to receive(:attempt_redaction).with(unresolved_request)
        expect(job).not_to receive(:attempt_redaction).with(stale_but_redacted_request)

        job.perform
      end
    end

    describe '#eligible_requests_for_redaction' do
      let(:job) { described_class.new }

      # Define requests specific to this context for isolation
      # Ensure definitions consistently include necessary traits for eligibility checks.
      let!(:expired_request) { create(:power_of_attorney_request, :with_expiration, :with_form_submission) }
      let!(:stale_request) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission, resolution_created_at: 61.days.ago)
      end
      let!(:recent_request) do
        create(:power_of_attorney_request, :with_declination, :with_form_submission, resolution_created_at: 1.day.ago)
      end
      let!(:unresolved_request) { create(:power_of_attorney_request) }
      let!(:stale_but_redacted_request) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission, resolution_created_at: 61.days.ago,
                                                                                    redacted_at: 1.day.ago)
      end

      it 'returns requests that are expired or stale processed and unredacted' do
        # Use send to test private methods
        eligible_requests = job.send(:eligible_requests_for_redaction)

        expect(eligible_requests).to include(expired_request, stale_request)
        expect(eligible_requests).not_to include(recent_request, unresolved_request, stale_but_redacted_request)
      end

      # Eager loading test removed (used non-standard matcher).
      # Consider using `bullet` gem in dev/test or manual checks if N+1 concerns arise.
    end

    describe '#expired_request_ids' do
      let(:job) { described_class.new }
      let!(:expired_request) { create(:power_of_attorney_request, :with_expiration) }
      let!(:accepted_request) { create(:power_of_attorney_request, :with_acceptance) }
      let!(:redacted_expired_request) { create(:power_of_attorney_request, :with_expiration, redacted_at: 1.day.ago) }

      it 'returns the ids of unredacted expired requests' do
        # Should only include the ID of the expired request that hasn't been redacted yet
        expect(job.send(:expired_request_ids)).to contain_exactly(expired_request.id)
      end
    end

    describe '#stale_processed_request_ids' do
      let(:job) { described_class.new }
      let!(:stale_accepted_request) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission, resolution_created_at: 61.days.ago)
      end
      # Declined requests might not strictly need form_submission for the .processed scope itself
      let!(:stale_declined_request) do
        create(:power_of_attorney_request, :with_declination, resolution_created_at: 61.days.ago)
      end
      let!(:recent_accepted_request) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission, resolution_created_at: 1.day.ago)
      end
      # Should be excluded by .processed scope
      let!(:stale_expired_request) do
        create(:power_of_attorney_request, :with_expiration, resolution_created_at: 61.days.ago)
      end
      let!(:stale_unresolved_request) { create(:power_of_attorney_request, created_at: 61.days.ago) } # No resolution
      # Already redacted
      let!(:stale_redacted_request) do
        create(:power_of_attorney_request, :with_acceptance, :with_form_submission, resolution_created_at: 61.days.ago,
                                                                                    redacted_at: 1.day.ago)
      end

      it 'returns the ids of stale, processed (non-expired), unredacted requests' do
        expect(job.send(:stale_processed_request_ids)).to contain_exactly(stale_accepted_request.id,
                                                                          stale_declined_request.id)
      end
    end

    describe '#process_requests' do
      let(:job) { described_class.new }
      # Use build_stubbed as we don't need persistence and are stubbing attempt_redaction
      let(:request1) { build_stubbed(:power_of_attorney_request) }
      let(:request2) { build_stubbed(:power_of_attorney_request) }
      let(:requests) { [request1, request2] }

      it 'attempts to redact each request and returns a count of successes and errors' do
        # Stub attempt_redaction to control behavior for this test
        allow(job).to receive(:attempt_redaction).with(request1).and_return(true)
        allow(job).to receive(:attempt_redaction).with(request2).and_return(false)

        results = job.send(:process_requests, requests)
        expect(results).to eq({ redacted: 1, errors: 1 })
      end
    end

    describe '#attempt_redaction' do
      let(:job) { described_class.new }
      # Use build_stubbed as we are stubbing the actual redaction call (#redact_request)
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
      # Create a request with necessary associations for redaction logic
      let!(:request) { create(:power_of_attorney_request, :with_declination, :with_form_submission) }
      # Get references to associated objects for easier expectation setting
      let!(:form) { request.power_of_attorney_form }
      let!(:submission) { request.power_of_attorney_form_submission }
      let!(:resolution) { request.resolution }

      it 'redacts the request within a transaction' do
        expect(request).to receive(:transaction).and_call_original
        job.send(:redact_request, request)
        expect(request.reload.redacted_at).to be_present
      end

      it 'logs the request redaction' do
        expect(job).to receive(:log_request_redaction).with(request)
        job.send(:redact_request, request)
      end

      it 'destroys the associated form' do
        expect do
          job.send(:redact_request, request)
        end.to change { AccreditedRepresentativePortal::PowerOfAttorneyForm.exists?(form.id) }.from(true).to(false)
      end

      it 'nullifies submission data' do
        # Ensure submission has data to be nullified first, bypassing validations for setup.
        submission.update!(
          service_response_ciphertext: 'encrypted_data',
          error_message_ciphertext: 'encrypted_error', encrypted_kms_key: 'key'
        )
        submission.reload # Ensure setup is reflected before redaction

        job.send(:redact_request, request)
        submission.reload

        expect(submission.service_response_ciphertext).to be_nil
        expect(submission.error_message_ciphertext).to be_nil
        # NOTE: If this expectation fails, check for callbacks or other logic in the
        # PowerOfAttorneyFormSubmission model that might prevent encrypted_kms_key from being nullified.
        expect(submission.encrypted_kms_key).to be_nil
      end

      it 'nullifies the resolution reason' do
        # Setup: Ensure a reason exists (assuming update! works here, otherwise use update_column)
        resolution.update!(reason: 'Some reason')
        job.send(:redact_request, request)
        expect(resolution.reload.reason).to be_nil
      end

      it 'marks the request as redacted by touching redacted_at' do
        expect do
          job.send(:redact_request, request)
        end.to change { request.reload.redacted_at }.from(nil).to(be_present)
      end

      context 'when form is already destroyed or nil' do
        before do
          # Ensure form is gone from DB for this context
          request.power_of_attorney_form&.destroy!
          request.reload # Clear association cache
        end

        it 'handles missing form without error' do
          expect(request.power_of_attorney_form).to be_nil
          expect { job.send(:redact_request, request) }.not_to raise_error
          expect(request.reload.redacted_at).to be_present
        end
      end

      context 'when submission is nil' do
        before do
          # Ensure submission is gone from DB for this context
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
          # NOTE: Job eligibility logic heavily relies on resolution existing.
          # Redacting an eligible request should always have a resolution present.
          # This test mainly ensures nil safety if redact_request were called independently.
          expect { job.send(:redact_request, request) }.not_to raise_error
          expect(request.reload.redacted_at).to be_present
        end
      end

      it 'retains skeleton PowerOfAttorneyRequest fields after redaction' do
        # Capture original non-PII values before redaction
        original_claimant_id = request.claimant_id
        original_claimant_type = request.claimant_type
        original_poa_code = request.power_of_attorney_holder_poa_code
        original_poa_type = request.power_of_attorney_holder_type
        original_created_at = request.created_at # Should not change

        # Perform the redaction
        job.send(:redact_request, request)
        request.reload

        # Verify skeleton fields remain unchanged
        expect(request.claimant_id).to eq(original_claimant_id)
        expect(request.claimant_type).to eq(original_claimant_type)
        expect(request.power_of_attorney_holder_poa_code).to eq(original_poa_code)
        expect(request.power_of_attorney_holder_type).to eq(original_poa_type)
        expect(request.created_at).to eq(original_created_at)

        # Verify redacted_at is set (already covered, but good for context)
        expect(request.redacted_at).to be_present
      end

      it 'retains skeleton Resolution fields (excluding reason) after redaction' do
        # Ensure resolution exists from let! block
        expect(resolution).to be_present

        # Capture original non-PII values before redaction (reason nullification tested elsewhere)
        # Adjust these field names based on your actual Resolution model schema
        original_resolving_type = resolution.resolving_type
        original_resolving_id = resolution.resolving_id
        original_poa_request_id = resolution.power_of_attorney_request_id
        original_created_at = resolution.created_at # Should not change

        # Perform the redaction
        job.send(:redact_request, request)
        resolution.reload

        # Verify skeleton fields remain unchanged
        expect(resolution.resolving_type).to eq(original_resolving_type)
        expect(resolution.resolving_id).to eq(original_resolving_id)
        expect(resolution.power_of_attorney_request_id).to eq(original_poa_request_id)
        expect(resolution.created_at).to eq(original_created_at)

        # Verify reason is nil (already covered, but good for context)
        expect(resolution.reason).to be_nil
      end
    end

    describe 'logging methods' do
      let(:job) { described_class.new }
      # Use build_stubbed for efficiency as only ID/message needed for logging format tests
      let(:request_id) { SecureRandom.uuid }
      let(:request) { build_stubbed(:power_of_attorney_request, id: request_id) }
      let(:error) { StandardError.new('Test error') }

      it '#log_start logs the start message' do
        expect(Rails.logger).to receive(:info).with(/Starting job/)
        job.send(:log_start)
      end

      it '#log_request_redaction logs the request redaction' do
        # Use the specific request_id in the expectation
        expect(Rails.logger).to receive(:info).with(/Redacting PowerOfAttorneyRequest ##{request.id}/)
        job.send(:log_request_redaction, request)
      end

      it '#log_redaction_error logs the error details' do
        # Mock the backtrace for consistent error logging format test
        allow(error).to receive(:backtrace).and_return(['line 1', 'line 2'])
        # Use the specific request_id in the expectation
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
