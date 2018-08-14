# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526
      include Sidekiq::Worker

      FORM_ID = '21-526EZ'
      RETRY = 15 # Retry count

      sidekiq_options retry: RETRY

      # Set retry delay (in seconds) with an exponential back off
      sidekiq_retry_in do |count|
        (2**count - 1) / 2
      end

      # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
      sidekiq_retries_exhausted do |_msg, _ex|
        transaction.update_transaction(jid, :exhausted)
      end

      def perform(user_uuid, form_content, uploads)
        user = User.find(user_uuid)

        transaction.start(user, jid)
        response = service(user).submit_form(form_content)
        transaction.update_transaction(jid, :received, response.attributes)

        # Delete SiP form on successfull submission
        InProgressForm.form_for_user(FORM_ID, user)&.destroy
        EVSS::IntentToFile::ResponseStrategy.delete("#{user.uuid}:compensation")

        EVSS::DisabilityCompensationForm::SubmitUploads.start(user, response.claim_id, uploads) if uploads.present?
      rescue EVSS::DisabilityCompensationForm::ServiceException => e
        if e.status_code.between?(500, 600)
          transaction.update_transaction(jid, :retrying, e.messages)
          raise e
        end
        transaction.update_transaction(jid, :non_retryable_error, e.messages)
      rescue Common::Exceptions::GatewayTimeout => e
        transaction.update_transaction(jid, :retrying, e.message)
        raise e
      rescue StandardError => e
        # Treat unexpected errors as hard failures
        # This includes BackeEndService Errors (including 403's)
        transaction.update_transaction(jid, :non_retryable_error, e.to_s)
      end

      private

      def service(user)
        EVSS::DisabilityCompensationForm::Service.new(user)
      end

      def transaction
        AsyncTransaction::EVSS::VA526ezSubmitTransaction
      end
    end
  end
end
