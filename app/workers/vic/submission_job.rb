module VIC
  class SubmissionJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(vic_submission_id, form)
      parsed_form = JSON.parse(form)
      response = Service.new.submit(parsed_form)

      VICSubmission.find(vic_submission_id).update_attributes!(
        response: response
      )
    end
  end
end
