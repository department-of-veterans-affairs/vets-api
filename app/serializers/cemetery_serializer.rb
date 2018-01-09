# frozen_string_literal: true

class CemeterySerializer < ActiveModel::Serializer
  attribute :id

  attribute(:cemetery_id) { object.id }
  attribute :name
  attribute :cemetery_type
  attribute :num
end
