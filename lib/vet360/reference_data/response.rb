# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ReferenceData
    class Response < Vet360::Response
      attribute :reference_data, Array[Hash]

      def self.from(response, key)
        new(response&.status, reference_data: response.body[key])
      end
    end
  end
end
