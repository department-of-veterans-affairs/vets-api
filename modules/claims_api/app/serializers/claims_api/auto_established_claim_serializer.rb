# frozen_string_literal: true

module ClaimsApi
  class AutoEstablishedClaimSerializer < ActiveModel::Serializer
    attribute :id
    attribute :status
    attribute :evss_id
  end
end
