# frozen_string_literal: true

module VIC
  class SubmissionJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(vic_submission_id, form)
      @vic_submission_id = vic_submission_id
      parsed_form = JSON.parse(form)

      client = Restforce.new(
        oauth_token: VIC::Service.new.get_oauth_token,
        instance_url: VIC::Configuration::SALESFORCE_INSTANCE_URL,
        api_version: '41.0'
      )

      client.post('/services/apexrest/VICRequest/', company: 'GenePoint')

      response = Service.new.submit(parsed_form)

      submission.update_attributes!(
        response: response
      )
    rescue StandardError
      submission.update_attributes!(state: 'failed')
      raise
    end

    def submission
      @submission ||= VICSubmission.find(@vic_submission_id)
    end
  end
end
