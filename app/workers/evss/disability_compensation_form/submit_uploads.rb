# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitUploads
      include Sidekiq::Worker

      def self.start(uuid)
        puts 'SubmitUploads#start'
        batch = Sidekiq::Batch.new
        batch.on(
          :success,
          self,
          'uuid' => uuid,
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
        puts 'SubmitUploads#perform'
        # TODO: POST upload
      end

      def on_success(status, options)
        puts 'SubmitUploads#on_success'
      end
    end
  end
end
