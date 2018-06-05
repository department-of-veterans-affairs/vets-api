# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ReferenceData
    class ReferenceDataResponse < Vet360::Response
      attribute :reference_data, Hash

      def self.from(response)
        new(response&.status, reference_data: response.body)
      end
    end
  end
end
