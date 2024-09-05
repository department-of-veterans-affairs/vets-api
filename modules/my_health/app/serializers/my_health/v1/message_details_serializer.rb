# frozen_string_literal: true

module MyHealth
  module V1
    class MessageDetailsSerializer < MessagesSerializer
      include JSONAPI::Serializer

      set_id :message_id

      attribute :message_id, &:id
      attribute :body, &:message_body
      attribute :message_id
      attribute :thread_id
      attribute :folder_id
      attribute :message_body
      attribute :draft_date
      attribute :to_date
      attribute :has_attachments

      attribute :attachments do |object|
        (1..4).each_with_object([]) do |i, array|
          unless object.send("attachment#{i}_id").nil?
            attachment = {
              id: object.send("attachment#{i}_id"),
              message_id: object.message_id,
              name: object.send("attachment#{i}_name"),
              attachment_size: object.send("attachment#{i}_size"),
              download:
                MyHealth::UrlHelper.new.v1_message_attachment_url(
                  object.message_id, object.send("attachment#{i}_id")
                )
            }
            array << attachment
          end
        end
      end

      link :self do |object|
        MyHealth::UrlHelper.new.v1_message_url(object.message_id)
      end
    end
  end
end
