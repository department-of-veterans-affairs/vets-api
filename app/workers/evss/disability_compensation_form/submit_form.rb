# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm
      include Sidekiq::Worker

      def self.start(uuid)
        puts 'SubmitForm#start'
        batch = Sidekiq::Batch.new
        batch.on(
          :success,
          self,
          'uuid' => uuid,
        )
        batch.jobs do
          perform_async(uuid)
        end
      end

      def perform(uuid)
        puts 'SubmitForm#perform'
        # TODO: POST form
        # TODO: store claim id in db
      end

      def on_success(status, options)
        puts 'SubmitForm#on_success'
        uuid = options['uuid']
        EVSS::DisabilityCompensationForm::SubmitUploads.start(uuid)
      end
    end
  end
end
