# frozen_string_literal: true
require 'evss/response'

module EVSS
  module AWS
    module ReferenceData
      class DisabilitiesResponse < EVSS::Response
        attribute :disabilities, Array[EVSS::ReferenceData::Disability]

        def initialize(status, response = nil)
        	# TODO : tell evss to rename disability to disabilities
          super(status, disabilities: response&.body&.dig('disability'))
        end
      end
    end
  end
end
