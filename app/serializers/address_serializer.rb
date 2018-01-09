# frozen_string_literal: true

class AddressSerializer < ActiveModel::Serializer
  attribute :address
  attribute :control_information

  def id
    nil
  end
end
