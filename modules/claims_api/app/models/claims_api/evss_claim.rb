# frozen_string_literal: true

module ClaimsApi
  class EVSSClaim
    include Virtus.model
    include ActiveModel::Serialization

    attribute :evss_id, Integer
    attribute :data, Hash
    attribute :list_data, Hash

    def requested_decision
      false
    end

    def updated_at
      nil
    end
  end
end
