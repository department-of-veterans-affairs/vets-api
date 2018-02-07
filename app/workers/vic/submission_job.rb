# frozen_string_literal: true

module VIC
  class SubmissionJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(vic_submission_id, form)
      @vic_submission_id = vic_submission_id
      parsed_form = JSON.parse(form)

      # client = Restforce.new(
      #   oauth_token: VIC::Service.new.get_oauth_token,
      #   instance_url: VIC::Configuration::SALESFORCE_INSTANCE_URL,
      #   api_version: '41.0'
      # )

      # payload = {
      #   service_branch: 'Army',
      #   email: 'foo@foo.com',
      #   veteran_full_name: {
      #     first: 'Test',
      #     last: 'Guy'
      #   },
      #   veteran_address: {
      #     city: 'Roanoke',
      #     country: 'US',
      #     postal_code: '53130',
      #     state: 'WI',
      #     street: '123 Main St'
      #   },
      #   profile_data: {
      #     sec_ID: '0000027892',
      #     active_ICN: '1012832025V743496',
      #     historical_ICN: [],
      #     SSN: '111223333'
      #   },
      #   phone: '5555551212'
      # }

      # client.post('/services/apexrest/VICRequest/', payload)

      # client.create(
      #   'Attachment',
      #   ParentId: '500350000018JWGAA2',
      #   Name: 'foo.pdf',
      #   Body: Restforce::UploadIO.new(
      #     Rails.root.join('spec', 'fixtures', 'preneeds', 'extras.pdf').to_s,
      #     'application/pdf'
      #   )
      # )

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
