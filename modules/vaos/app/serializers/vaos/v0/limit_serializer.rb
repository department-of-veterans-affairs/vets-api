# frozen_string_literal: true

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
