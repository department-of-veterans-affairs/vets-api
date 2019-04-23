# frozen_string_literal: true

module ClaimsApi
  class IntentToFileSerializer < ActiveModel::Serializer
    attribute :creation_date
    attribute :expiration_date
    attribute :type
    attribute :status
  end
end
