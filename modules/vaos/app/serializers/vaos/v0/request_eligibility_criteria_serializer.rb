# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'fast_jsonapi'

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
# :nocov:
