# frozen_string_literal: true

require 'dmc/base_service'
require 'dmc/fsr_configuration'
require 'dmc/responses/fsr_response'

module DMC
  class FSRService < DMC::BaseService
    configuration DMC::FSRConfiguration
    STATSD_KEY_PREFIX = 'api.dmc'

    def submit_financial_status_report(form)
      with_monitoring_and_error_handling do
        form = camelize(form)
        DMC::FSRResponse.new(perform(:post, 'financial-status-report/formtopdf', form).body)
      end
    end

    private

    def camelize(hash)
      hash.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
    end
  end
end
