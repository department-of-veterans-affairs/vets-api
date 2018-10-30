# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class AncillaryJobs
      def initialize(user_uuid, auth_headers, saved_claim_id, submission_data)
        @user_uuid = user_uuid
        @auth_headers = auth_headers
        @saved_claim_id = saved_claim_id
        @submission_data = submission_data
      end

      def perform(bid, claim_id)
        workflow_batch = Sidekiq::Batch.new(bid)
        workflow_batch.jobs do
          submit_uploads(claim_id) if @submission_data['form526_uploads'].present?
          submit_form_4142(claim_id) if @submission_data['form4142'].present?
          submit_form_0781(claim_id) if @submission_data['form0781'].present?
          cleanup
        end
      end

      private

      def submit_uploads(claim_id)
        @submission_data['form526_uploads'].each do |upload_data|
          EVSS::DisabilityCompensationForm::SubmitUploads.perform_async(
            @auth_headers, claim_id, @saved_claim_id, @submission_id, upload_data
          )
        end
      end

      def submit_form_4142(claim_id)
        CentralMail::SubmitForm4142Job.perform_async(
          claim_id, @saved_claim_id, @submission_id, @submission_data['form4142']
        )
      end

      def submit_form_0781(claim_id)
        EVSS::DisabilityCompensationForm::SubmitForm0781.perform_async(
          @auth_headers, claim_id, @saved_claim_id, @submission_id, @submission_data['form0781']
        )
      end

      def cleanup
        EVSS::DisabilityCompensationForm::SubmitForm526Cleanup.perform_async(@user_uuid)
      end
    end
  end
end
