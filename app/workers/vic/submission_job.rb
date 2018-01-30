module VIC
  class SubmissionJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(vic_submission_id, form)
      @vic_submission_id = vic_submission_id
      parsed_form = JSON.parse(form)
      response = Service.new.submit(parsed_form)

      submission.update_attributes!(
        response: response
      )
    rescue
      submission.update_attributes!(state: 'failed')
      raise
    end

    def submission
      @submission ||= VICSubmission.find(@vic_submission_id)
    end
  end
end
