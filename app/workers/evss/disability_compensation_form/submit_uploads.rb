# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitUploads
      include Sidekiq::Worker

      FORM_TYPE = '21-526EZ'

      def self.start(uuid)
        batch = Sidekiq::Batch.new
        batch.on(
          :success,
          self,
          'uuid' => uuid
        )
        batch.jobs do
          claim_id = get_claim_id(uuid)
          uploads = get_uploads(uuid)
          uploads.each { |u| perform_async(uuid, u[:guid], claim_id) }
        end
      end

      def self.get_claim_id(_uuid)
        nil
      end

      def self.get_uploads(_uuid)
        nil
      end

      def perform(uuid, guid, claim_id)
        # TODO: process upload
      end

      def on_success(_status, _options)
        # TODO: send email notification
      end
    end
  end
end
