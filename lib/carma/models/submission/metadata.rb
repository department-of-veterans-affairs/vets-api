# frozen_string_literal: true

module CARMA
  module Models
    class Submission
      class Metadata < CARMA::Models::Base
        request_payload_key :claim_id

        attr_reader :claim_id

        def initialize(args = {})
          @claim_id = args[:claim_id]
        end
      end
    end
  end
end
