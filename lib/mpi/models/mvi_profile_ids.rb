# frozen_string_literal: true

module MPI
  module Models
    module MviProfileIds
      extend ActiveSupport::Concern

      included do
        attribute :active_mhv_ids,      array: true, default: []
        attribute :birls_id,            :string
        attribute :birls_ids,           array: true, default: []
        attribute :cerner_facility_ids, array: true, default: []
        attribute :cerner_id,           :string
        attribute :edipi,               :string
        attribute :edipis,              array: true, default: []
        attribute :full_mvi_ids,        array: true, default: []
        attribute :icn,                 :string
        attribute :icn_with_aaid,       :string
        attribute :mhv_ids,             array: true, default: []
        attribute :mhv_ien,             :string
        attribute :mhv_iens,            array: true, default: []
        attribute :participant_id,      :string
        attribute :participant_ids,     array: true, default: []
        attribute :sec_id,              :string
        attribute :sec_ids,             array: true, default: []
        attribute :vet360_id,           :string
        attribute :vha_facility_hash,   hash: true, default: {}
        attribute :vha_facility_ids,    array: true, default: []

        def mhv_correlation_id
          active_mhv_ids&.first
        end
      end
    end
  end
end
