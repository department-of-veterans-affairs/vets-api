# frozen_string_literal: true
require 'evss/response'

module EVSS
  module AWS
    module ReferenceData
      class IntakeSitesResponse < EVSS::Response
        attribute :intake_sites, Array[String]

        def initialize(status, response = nil)
          super(status, intake_sites: response&.body&.dig('intake_sites'))
        end
      end
    end
  end
end
