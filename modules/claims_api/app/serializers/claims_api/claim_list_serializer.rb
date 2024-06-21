# frozen_string_literal: true

require_relative 'concerns/claim_base'

module ClaimsApi
  class ClaimListSerializer
    include JSONAPI::Serializer
    include Concerns::ClaimBase

    set_type :evss_claims

    set_id do |object|
      object&.evss_id
    end

    attribute :status do |object|
      phase = phase_from_keys(object, 'status')
      object.status_from_phase(phase)
    end

    def self.object_data(object)
      object.list_data
    end
  end
end
