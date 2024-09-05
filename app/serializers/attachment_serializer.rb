# frozen_string_literal: true

class AttachmentSerializer
  include JSONAPI::Serializer
  singleton_class.include Rails.application.routes.url_helpers

  set_type :attachments

  attribute :name
  attribute :message_id
  attribute :attachment_size

  link :download do |object|
    v0_message_attachment_url(object.message_id, object.id)
  end
end
