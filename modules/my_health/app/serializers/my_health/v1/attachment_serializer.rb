# frozen_string_literal: true

module MyHealth
  module V1
    class AttachmentSerializer < ActiveModel::Serializer
      attribute :id
      attribute :name
      attribute :message_id
      attribute :attachment_size

      link(:download) { MyHealth::UrlHelper.new.v1_message_attachment_url(object.message_id, object.id) }
    end
  end
end
