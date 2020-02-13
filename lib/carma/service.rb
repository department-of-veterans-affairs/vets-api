# frozen_string_literal: true

require 'common/client/base'

module CARMA
  class Service < Salesforce::Service
    configuration CARMA::Configuration

    STATSD_KEY_PREFIX = 'api.carma'

    def submit(form)
      client = get_client
      response_body = with_monitoring do
        client.post('/services/apexrest/10-10CG-application', form).body
      end

      response_body.slice('case_id')
    end
  end
end
