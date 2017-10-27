# frozen_string_literal: true
class PreneedsAttachmentTypeSerializer < ActiveModel::Serializer
  attribute :attachment_type_id
  attribute :description

  def id
    object.attachment_type_id
  end
end
