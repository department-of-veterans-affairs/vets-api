# frozen_string_literal: true

module MPI
  module Models
    module MviProfileIds
      include Virtus.module

      attribute :full_mvi_ids, Array[String]
      attribute :icn, String
      attribute :icn_with_aaid, String
      attribute :mhv_ids, Array[String]
      attribute :active_mhv_ids, Array[String]
      attribute :vha_facility_ids, Array[String]
      attribute :vha_facility_hash, Hash
      attribute :edipi, String
      attribute :participant_id, String
      attribute :birls_id, String
      attribute :birls_ids, Array[String]
      attribute :sec_id, String
      attribute :vet360_id, String
      attribute :historical_icns, Array[String]
      attribute :cerner_facility_ids, Array[String]
      attribute :cerner_id, String

      def mhv_correlation_id
        @active_mhv_ids&.first
      end
    end
  end
end
