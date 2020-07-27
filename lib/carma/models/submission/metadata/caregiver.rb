# frozen_string_literal: true

module CARMA
  module Models
    class Submission
      class Metadata
        class Caregiver < CARMA::Models::Base
          request_payload_key :icn

          attr_accessor :icn

          def initialize(args = {})
            @icn = args[:icn]
          end
        end
      end
    end
  end
end
