module VIC
  class SubmissionJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(vic_submission_id)
      response = Service.new(form)

      VICSubmission.find(vic_submission_id).update_attributes!(
        response: response
      )
    end
  end
end
