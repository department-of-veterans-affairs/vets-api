# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm
      include Sidekiq::Worker

      def self.start(uuid)
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
        user = User.find(uuid: uuid) #untested
        form_type = '21-526EZ'
        form = InProgressForm.form_for_user(form_type, user) #untested
        service = DisabilityCompensationForm.new(user) #untested
        response = service.submit_form(form.form_data) #untested
        DisabilityCompensationSubmission.create!( #untested
          user_uuid: uuid,
          form_type: form_type,
          claim_id: response.claim_id,
        )
      end

      def on_success(status, options)
        uuid = options['uuid']
        EVSS::DisabilityCompensationForm::SubmitUploads.start(uuid)
      end
    end
  end
end
