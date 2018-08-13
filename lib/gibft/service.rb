# frozen_string_literal: true

module Gibft
  class Service < Salesforce::Service
    configuration Gibft::Configuration

    CONSUMER_KEY = Settings['salesforce-gibft'].consumer_key
    SIGNING_KEY_PATH = Settings['salesforce-gibft'].signing_key_path
    # TODO: staging and prod username
    SALESFORCE_USERNAME = 'vetsgov-devops-cl-feedback@listserv.gsa.gov.rdtcddev'

    def submit(form)
      client = get_client
      response_body = client.post('/services/apexrest/educationcomplaint', form).body
      Raven.extra_context(submit_response_body: response_body)

      response_body.slice('case_id', 'case_number')
    end
  end
end
