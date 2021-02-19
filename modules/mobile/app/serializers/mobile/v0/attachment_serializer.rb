# frozen_string_literal: true

module Mobile
  module V0
    class AttachmentSerializer < ActiveModel::Serializer
      include Mobile::Engine.routes.url_helpers

      attribute :id
      attribute :name
      attribute :message_id

      link(:download) { Mobile::UrlHelper.new.v0_message_attachment_url(object.message_id, object.id) }
    end
  end
end
