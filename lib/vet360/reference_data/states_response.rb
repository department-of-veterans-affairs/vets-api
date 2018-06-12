# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ReferenceData
    class StatesResponse < Response
      attribute :states, Array[Hash]

      def self.from(response)
        new(response.status, states: response.body['state_list'])
      end
    end
  end
end
