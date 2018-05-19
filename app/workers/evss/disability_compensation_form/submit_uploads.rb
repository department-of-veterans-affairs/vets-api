# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitUploads
      include Sidekiq::Worker

      def self.start(uuid)
        batch = Sidekiq::Batch.new
        batch.on(
          :success,
          self,
          'uuid' => uuid
        )
        batch.jobs do
          # TODO: fetch claim id from db
          # TODO: for each upload call perform_async
          image_id = 'abc123'
          claim_id = 'def456'
          perform_async(image_id, claim_id)
        end
      end

      def perform(image_id, claim_id)
        # TODO: POST upload
      end

      def on_success(status, options) end
    end
  end
end
