# frozen_string_literal: true

require 'jsonapi/serializer'

module VAOS
  module V0
    class LimitSerializer
      include JSONAPI::Serializer

      attributes :number_of_requests,
                 :request_limit
    end
  end
end
