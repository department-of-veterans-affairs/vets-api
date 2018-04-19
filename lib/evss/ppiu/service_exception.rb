# frozen_string_literal: true

require 'evss/service_exception'

module EVSS
  module PPIU
    class ServiceException < EVSS::ServiceException
      ERROR_MAP = {
        exception: 'evss.external_service_unavailable',
        cnp: 'evss.ppiu.unprocessable_entity',
        indicators: 'evss.ppiu.unprocessable_entity',
        modelvalidators: 'evss.ppiu.unprocessable_entity'
      }.freeze
    end
  end
end
