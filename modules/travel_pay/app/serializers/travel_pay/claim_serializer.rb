# frozen_string_literal: true

module TravelPay
  class ClaimSerializer < ActiveModel::Serializer
    attributes :id, :modifiedOn
  end
end
