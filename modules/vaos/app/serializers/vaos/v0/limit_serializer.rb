# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'fast_jsonapi'

module VAOS
  module V0
    class LimitSerializer
      include FastJsonapi::ObjectSerializer

      set_id :institution_code
      attributes :number_of_requests,
                 :request_limit
    end
  end
end
# :nocov:
