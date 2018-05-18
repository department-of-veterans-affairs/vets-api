# frozen_string_literal: true

module DisabilityCompensationForm
  class ProcessFormAndUploads
    include Sidekiq::Worker

    def perform(form_id, user)
      in_progress_form = InProgressForm.form_for_user(form_id, user)

      # in_progress_form.guids.each do |guid|
      #   something
      # end
      
      # submit something to document service API
    end

  end
end
