# frozen_string_literal: true

require_relative 'base'
require_relative 'caregiver'
require_relative 'veteran'

module CARMA
  module Models
    class Metadata < Base
      request_payload_key :claim_id,
                          :claim_guid,
                          :submitted_at,
                          :veteran,
                          :primary_caregiver,
                          :secondary_caregiver_one,
                          :secondary_caregiver_two

      attr_accessor       :claim_id,
                          :claim_guid,
                          :submitted_at

      attr_reader         :veteran,
                          :primary_caregiver,
                          :secondary_caregiver_one,
                          :secondary_caregiver_two

      def initialize(args = {})
        @claim_id = args[:claim_id]
        @claim_guid = args[:claim_guid]
        @submitted_at = args[:submitted_at]

        self.veteran = args[:veteran] || {}
        self.primary_caregiver = args[:primary_caregiver]
        self.secondary_caregiver_one = args[:secondary_caregiver_one]
        self.secondary_caregiver_two = args[:secondary_caregiver_two]
      end

      def veteran=(veteran_data_hash)
        @veteran = CARMA::Models::Veteran.new(veteran_data_hash)
      end

      def primary_caregiver=(pc_metadata_hash)
        @primary_caregiver = if pc_metadata_hash.nil?
                               nil
                             else
                               Caregiver.new(pc_metadata_hash)
                             end
      end

      def secondary_caregiver_one=(sc_one_metadata_hash)
        @secondary_caregiver_one = if sc_one_metadata_hash.nil?
                                     nil
                                   else
                                     Caregiver.new(sc_one_metadata_hash)
                                   end
      end

      def secondary_caregiver_two=(sc_two_metadata_hash)
        @secondary_caregiver_two = if sc_two_metadata_hash.nil?
                                     nil
                                   else
                                     Caregiver.new(sc_two_metadata_hash)
                                   end
      end
    end
  end
end
