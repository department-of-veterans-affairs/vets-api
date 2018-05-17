# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm
      include Sidekiq::Worker

      def self.start(user)
        puts 'SubmitForm#start'
        batch = Sidekiq::Batch.new
        batch.on(
          :success,
          self,
          'uuid' => user.uuid,
        )
        batch.jobs do
          perform_async(uuid)
        end
      end

      def perform(user)
        response = EVSS::DisabilityCompensationForm::Service.new(user).submit_form(request.body.string)
      end

      def on_success(status, options)
        puts 'SubmitForm#on_success'
        uuid = options['uuid']
        EVSS::DisabilityCompensationForm::SubmitUploads.start(uuid)
      end
    end
  end
end
