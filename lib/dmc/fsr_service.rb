# frozen_string_literal: true

require 'common/client/base'
require 'dmc/fsr_configuration'
require 'dmc/responses/fsr_response'

module DMC
  class FSRService < Common::Client::Base

    configuration DMC::Configuration

    def submit_financial_status_report(form)
      FinancialStatusReportResponse(
        perform(:post, 'fsr', form).body
      )
    end
  end
end
