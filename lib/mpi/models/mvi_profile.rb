# frozen_string_literal: true

require_relative 'mvi_profile_address'
require_relative 'mvi_profile_relationship'
require 'vets/model'

module MPI
  module Models
    class MviProfile
      include Vets::Model

      attribute :search_token, String
      attribute :relationships, MviProfileRelationship, array: true, default: []
      attribute :id_theft_flag, Bool
      attribute :transaction_id, String
      attribute :given_names, String, array: true, default: []
      attribute :family_name, String
      attribute :preferred_names, String, array: true, default: []
      attribute :suffix, String
      attribute :gender, String
      attribute :birth_date, Vets::Type::DateTimeString
      attribute :deceased_date, Vets::Type::DateTimeString
      attribute :ssn, String
      attribute :address, MviProfileAddress
      attribute :home_phone, String
      attribute :person_types, String, array: true, default: []
      attribute :full_mvi_ids, String, array: true, default: []
      attribute :icn, String
      attribute :icn_with_aaid, String
      attribute :mhv_ids, String, array: true, default: []
      attribute :active_mhv_ids, String, array: true, default: []
      attribute :vha_facility_ids, String, array: true, default: []
      attribute :vha_facility_hash, Hash
      attribute :edipi, String
      attribute :edipis, String, array: true, default: []
      attribute :participant_id, String
      attribute :participant_ids, String, array: true, default: []
      attribute :mhv_ien, String
      attribute :mhv_iens, String, array: true, default: []
      attribute :birls_id, String
      attribute :birls_ids, String, array: true, default: []
      attribute :sec_id, String
      attribute :sec_ids, String, array: true, default: []
      attribute :vet360_id, String
      attribute :cerner_facility_ids, String, array: true, default: []
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
