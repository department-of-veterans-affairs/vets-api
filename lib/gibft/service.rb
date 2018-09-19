# frozen_string_literal: true

module Gibft
  class Service < Salesforce::Service
    configuration Gibft::Configuration

    CONSUMER_KEY = Settings['salesforce-gibft'].consumer_key
    SIGNING_KEY_PATH = Settings['salesforce-gibft'].signing_key_path
    SALESFORCE_USERNAMES = {
      'prod' => 'vetsgov-devops@listserv.gsa.gov',
      'uat' => 'vetsgov-devops-ci-feedback@listserv.gsa.gov.uat',
      'dev' => 'vetsgov-devops-ci-feedback@listserv.gsa.gov.rdtcddev'
    }.freeze
    SALESFORCE_USERNAME = SALESFORCE_USERNAMES[Settings['salesforce-gibft'].env]

    def submit(form)
      client = get_client
      response_body = client.post('/services/apexrest/educationcomplaint', form).body
      Raven.extra_context(submit_response_body: response_body)

      response_body.slice('case_id', 'case_number')
    end
  end
end
