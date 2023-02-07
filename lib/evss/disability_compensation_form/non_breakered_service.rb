# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'evss/service'
require 'evss/disability_compensation_form/non_breakered_configuration'
require 'evss/disability_compensation_auth_headers'
require_relative 'configuration'
require_relative 'rated_disabilities_response'
require_relative 'form_submit_response'
require_relative 'service_unavailable_exception'

module EVSS
  module DisabilityCompensationForm
    class NonBreakeredService < EVSS::DisabilityCompensationForm::Service
      configuration EVSS::DisabilityCompensationForm::NonBreakeredConfiguration
    end
  end
end
