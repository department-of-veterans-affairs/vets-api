# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmissionError < StandardError; end
    class SubmitForm
      include Sidekiq::Worker

      FORM_TYPE = '21-526EZ'

      def self.start(user, form_json)
        batch = Sidekiq::Batch.new
        batch.on(
          :success,
          self,
          'uuid' => user.uuid
        )
        batch.jobs do
          perform_async(user, form_json)
        end
      end

      def perform(user, form_json)
        response = EVSS::DisabilityCompensationForm::Service.new(user).submit_form(form_json)
        raise ArgumentError, 'missing claim_id' unless response.claim_id
        DisabilityCompensationSubmission.create(user_uuid: user.uuid, form_type: FORM_TYPE, claim_id: response.claim_id)
      rescue StandardError => error
        logger.error(
          'submit form failed', user: user.uuid, component: 'EVSS', form: '21-526EZ', detail: error.message
        )
        raise error
      end

      def on_success(_status, options)
        uuid = options['uuid']
        logger.info('submit form success', user: uuid, component: 'EVSS', form: '21-526EZ')

        EVSS::DisabilityCompensationForm::SubmitUploads.start(uuid)
      end
    end
  end
end
