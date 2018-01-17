# frozen_string_literal: true

class PreneedsAttachmentTypeSerializer < ActiveModel::Serializer
  attribute :id

  attribute(:attachment_type_id) { object.id }
  attribute :description
end
