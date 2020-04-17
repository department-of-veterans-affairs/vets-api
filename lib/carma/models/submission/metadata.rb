# frozen_string_literal: true

module CARMA
  module Models
    class Submission
      class Metadata < CARMA::Models::Base
        request_payload_key :claim_id,
                            :veteran,
                            :primary_caregiver,
                            :secondary_caregiver_one,
                            :secondary_caregiver_two

        attr_accessor       :claim_id

        attr_reader         :veteran,
                            :primary_caregiver,
                            :secondary_caregiver_one,
                            :secondary_caregiver_two

        def initialize(args = {})
          @claim_id = args[:claim_id]

          self.veteran = args[:veteran] || {}
          self.primary_caregiver = args[:primary_caregiver] || {}
          self.secondary_caregiver_one = args[:secondary_caregiver_one] if args[:secondary_caregiver_one]
          self.secondary_caregiver_two = args[:secondary_caregiver_two] if args[:secondary_caregiver_two]
        end

        def veteran=(args = {})
          @veteran = Metadata::Veteran.new(args)
        end

        def primary_caregiver=(args = {})
          @primary_caregiver = Metadata::Caregiver.new(args)
        end

        def secondary_caregiver_one=(args = {})
          @secondary_caregiver_one = Metadata::Caregiver.new(args)
        end

        def secondary_caregiver_two=(args = {})
          @secondary_caregiver_two = Metadata::Caregiver.new(args)
        end
      end
    end
  end
end
