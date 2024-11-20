# frozen_string_literal: true

require 'salesforce/service'
require_relative 'configuration'

module Gibft
  class Service < Salesforce::Service
    configuration Gibft::Configuration

    # Settings.salesforce-gibft
    CONSUMER_KEY = Settings['salesforce-gibft'].consumer_key
    SIGNING_KEY_PATH = Settings['salesforce-gibft'].signing_key_path
    SALESFORCE_USERNAMES = {
      'prod' => 'vetsgov-devops-ci-feedback@listserv.gsa.gov',
      'reg' => 'vetsgov-devops-ci-feedback@listserv.gsa.gov.reg',
      'dev' => 'vetsgov-devops-ci-feedback@listserv.gsa.gov.vacoedusit'
    }.freeze
    SALESFORCE_USERNAME = SALESFORCE_USERNAMES[Settings['salesforce-gibft'].env]
    STATSD_KEY_PREFIX = 'api.gibft'

    def submit(form)
      client = get_client
      response_body = with_monitoring do
        client.post('/services/apexrest/educationcomplaint', form).body
      end
      Sentry.set_extras(submit_response_body: response_body)

      response_body.slice('case_id', 'case_number')
    end
  end
end
