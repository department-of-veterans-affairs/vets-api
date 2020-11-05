# frozen_string_literal: true

require 'common/client/base'
require 'dmc/fsr_configuration'
require 'dmc/responses/dmc_response'

module DMC
  class FSRService < Common::Client::Base

    include Common::Client::Concerns::Monitoring

    configuration DMC::Configuration

    STATSD_KEY_PREFIX = 'api.dmc'

    def submit_financial_status_report(form)
      DMC::Response(
        perform(:post, 'fsr', form).body
      )
    end
  end
end
