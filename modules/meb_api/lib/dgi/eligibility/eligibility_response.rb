# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module Eligibility
      class EligibilityResponse < MebApi::DGI::Response
        attribute :veteran_is_eligbile, Boolean
        attribute :chapter, String

        def initialize(status, response = nil)
          attributes = {
            veteran_is_eligbile: response&.body&.fetch('veteran_is_eligible'),
            chapter: response&.body&.fetch('chapter')
          }

          super(status, attributes)
        end
      end
    end
  end
end
