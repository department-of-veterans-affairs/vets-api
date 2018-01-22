# frozen_string_literal: true

require 'common/models/attribute_types/date_time_string'

module MVI
  module Models
    # A vets primary address in MVI
    class MviProfileAddress
      include Virtus.model

      attribute :street, String
      attribute :city, String
      attribute :state, String
      attribute :postal_code, String
      attribute :country, String
    end

    # A vets attributes in MVI
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
      attribute :icn, String
      attribute :historical_icns, Array[String]
      attribute :mhv_ids, Array[String]
      attribute :vha_facility_ids, Array[String]
      attribute :edipi, String
      attribute :participant_id, String
      attribute :birls_id, String

      def mhv_correlation_id
        @mhv_ids&.first
      end

      def emis_request_options
        emis_opt = {}

        if edipi.present?
          emis_opt[:edipi] = edipi
        elsif icn.present?
          emis_opt[:icn] = icn
        end

        emis_opt
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
