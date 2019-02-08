# frozen_string_literal: true

require 'sidekiq'

module ClaimsApi
  class EvssDocumentUploader
    include Sidekiq::Worker

    # unsure of how these files will be represented
    def perform(files)
      # Reference these:
      # (in app/models/form526_submission.rb)
      # def submit_uploads
      #   # Put uploads on a one minute delay because of shared workload with EVSS
      #   EVSS::DisabilityCompensationForm::SubmitUploads.perform_in(60.seconds, id, form[FORM_526_UPLOADS])
      # end
      #
      # def submit_form_4142
      #   CentralMail::SubmitForm4142Job.perform_async(id)
      # end
      #
      # def submit_form_0781
      #   EVSS::DisabilityCompensationForm::SubmitForm0781.perform_async(id)
      # end
      #
      # def submit_form_8940
      #   EVSS::DisabilityCompensationForm::SubmitForm8940.perform_async(id)
      # end
      #
      # def cleanup
      #   EVSS::DisabilityCompensationForm::SubmitForm526Cleanup.perform_async(id)
      # end
    end
  end
end
