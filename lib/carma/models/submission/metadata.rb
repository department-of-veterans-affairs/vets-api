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
          self.secondary_caregiver_one = args[:secondary_caregiver_one]
          self.secondary_caregiver_two = args[:secondary_caregiver_two]
        end

        def veteran=(veteran_data_hash)
          @veteran = Metadata::Veteran.new(veteran_data_hash)
        end

        def primary_caregiver=(pc_metadata_hash)
          @primary_caregiver = Metadata::Caregiver.new(pc_metadata_hash)
        end

        def secondary_caregiver_one=(sc_one_metadata_hash)
          @secondary_caregiver_one = Metadata::Caregiver.new(sc_one_metadata_hash) unless sc_one_metadata_hash.nil?
        end

        def secondary_caregiver_two=(sc_two_metadata_hash)
          @secondary_caregiver_two = Metadata::Caregiver.new(sc_two_metadata_hash) unless sc_two_metadata_hash.nil?
        end
      end
    end
  end
end
