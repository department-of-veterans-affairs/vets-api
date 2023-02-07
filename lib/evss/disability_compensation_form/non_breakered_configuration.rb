# frozen_string_literal: true

require 'evss/configuration'

module EVSS
  module DisabilityCompensationForm
    class NonBreakeredConfiguration < EVSS::DisabilityCompensationForm::Configuration
      def set_evss_middlewares(faraday, snakecase: true)
        # faraday.use      :breakers # DONT USE BREAKERS
        faraday.use      EVSS::ErrorMiddleware
        faraday.use      Faraday::Response::RaiseError
        faraday.response :betamocks if mock_enabled?
        faraday.response :snakecase, symbolize: false if snakecase
        # calls to EVSS returns non JSON responses for some scenarios that don't make it through VAAFI
        # content_type: /\bjson$/ ensures only json content types are attempted to be parsed.
        faraday.response :json, content_type: /\bjson$/
        faraday.use :immutable_headers
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
