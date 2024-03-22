# frozen_string_literal: true

module TravelPay
  class ClaimSerializer < ActiveModel::Serializer
    attributes :id, :modified_on
  end
end
