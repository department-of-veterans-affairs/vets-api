# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module Forms
      module Response
        class SponsorResponse < MebApi::DGI::Response
          attribute :sponsors, Array

          def initialize(response = nil)
            attributes = {
              sponsors: response.body
            }

            super(response.status, attributes)
          end
        end
      end
    end
  end
end
