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
        user = User.find(uuid: uuid)
        form_type = '21-526EZ'
        form = InProgressForm.form_for_user(form_type, user)
        service = DisabilityCompensationForm.new(user)
        response = service.submit_form(form.form_data)
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
