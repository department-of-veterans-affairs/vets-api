# frozen_string_literal: true

class Post911GIBillAvailabilitySerializer < ActiveModel::Serializer
  attribute :is_available

  def id
    nil
  end
end
