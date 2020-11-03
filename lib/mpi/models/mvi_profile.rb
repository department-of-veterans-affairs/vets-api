# frozen_string_literal: true

require 'common/models/attribute_types/date_time_string'
require_relative 'mvi_profile_address'

module MPI
  module Models
    class MviProfile
      include Virtus.model

      attribute :given_names, Array[String]
      attribute :family_name, String
      attribute :suffix, String
      attribute :gender, String
      attribute :birth_date, Common::DateTimeString
      attribute :ssn, String
      attribute :address, MviProfileAddress
      attribute :home_phone, String
      attribute :full_mvi_ids, Array[String]
      attribute :icn, String
      attribute :icn_with_aaid, String
      attribute :mhv_ids, Array[String]
      attribute :active_mhv_ids, Array[String]
      attribute :vha_facility_ids, Array[String]
      attribute :edipi, String
      attribute :participant_id, String
      attribute :birls_id, String
      attribute :sec_id, String
      attribute :vet360_id, String
      attribute :historical_icns, Array[String]
      attribute :search_token, String
      attribute :cerner_facility_ids, Array[String]
      attribute :cerner_id, String

      def mhv_correlation_id
        @active_mhv_ids&.first
      end

      def normalized_suffix
        case @suffix
        when /jr\.?/i
          'Jr.'
        when /sr\.?/i
          'Sr.'
        when /iii/i
          'III'
        when /ii/i
          'II'
        when /iv/i
          'IV'
        end
      end
    end
  end
end
