# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneySerializer < ActiveModel::Serializer
    attributes :status, :date_request_accepted, :representative, :veteran, :current_poa
  end
end
