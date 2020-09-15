# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  module V0
    class RequestEligibilityCriteriaSerializer
      include FastJsonapi::ObjectSerializer

      attributes :id,
                 :request_settings,
                 :custom_request_settings
    end
  end
end
