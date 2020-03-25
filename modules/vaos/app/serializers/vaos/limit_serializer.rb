# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  class LimitSerializer
    include FastJsonapi::ObjectSerializer

    attributes :number_of_requests,
               :request_limit
  end
end
