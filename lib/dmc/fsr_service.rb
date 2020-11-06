# frozen_string_literal: true

require 'common/client/base'
require 'dmc/fsr_configuration'
require 'dmc/responses/dmc_response'

module DMC
  class FSRService < Common::Client::Base

    include Common::Client::Concerns::Monitoring

    configuration DMC::FSRConfiguration

    STATSD_KEY_PREFIX = 'api.dmc'

    def submit_financial_status_report(form)
      form = camelize(form)
      DMC::Response(perform(:post, 'formtopdf', form).body)
    end

    private

    def camelize(hash)
      hash.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
    end
  end
end
