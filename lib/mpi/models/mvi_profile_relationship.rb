# frozen_string_literal: true

require 'vets/model'

module MPI
  module Models
    class MviProfileRelationship
      include Vets::Model

      attribute :given_names, String, array: true
      attribute :family_name, String
      attribute :preferred_names, String, array: true
      attribute :suffix, String
      attribute :gender, String
      attribute :birth_date, Vets::Type::DateTimeString
      attribute :deceased_date, Vets::Type::DateTimeString
      attribute :ssn, String
      attribute :address, MviProfileAddress
      attribute :home_phone, String
      attribute :person_types, String, array: true
      attribute :full_mvi_ids, String, array: true
      attribute :icn, String
      attribute :icn_with_aaid, String
      attribute :mhv_ids, String, array: true
      attribute :active_mhv_ids, String, array: true
      attribute :vha_facility_ids, String, array: true
      attribute :vha_facility_hash, Hash
      attribute :edipi, String
      attribute :edipis, String, array: true
      attribute :participant_id, String
      attribute :participant_ids, String, array: true
      attribute :mhv_ien, String
      attribute :mhv_iens, String, array: true
      attribute :birls_id, String
      attribute :birls_ids, String, array: true
      attribute :sec_id, String
      attribute :sec_ids, String, array: true
      attribute :vet360_id, String
      attribute :cerner_facility_ids, String, array: true
      attribute :cerner_id, String

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

      def mhv_correlation_id
        @active_mhv_ids&.first
      end

    end
  end
end
