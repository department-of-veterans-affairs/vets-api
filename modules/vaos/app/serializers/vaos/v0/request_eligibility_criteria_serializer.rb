# frozen_string_literal: true

require 'jsonapi/serializer'

module VAOS
  module V0
    class RequestEligibilityCriteriaSerializer
      include JSONAPI::Serializer

      attributes :id,
                 :request_settings,
                 :custom_request_settings
    end
  end
end
