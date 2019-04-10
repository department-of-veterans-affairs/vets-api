# frozen_string_literal: true

module ClaimsApi
  class AutoEstablishedClaimSerializer < ActiveModel::Serializer
    attribute :token
    attribute :status
    attribute :evss_id
  end
end
