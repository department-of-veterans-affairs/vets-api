# frozen_string_literal: true

module AskVAApi
  module Contents
    class Entity
      attr_reader :id,
                  :name,
                  :parent_id,
                  :description,
                  :requires_authentication,
                  :allow_attachments,
                  :rank_order,
                  :display_name,
                  :topic_type,
                  :contact_preferences

      def initialize(info)
        @id = info[:Id]
        @name = info[:Name]
        @parent_id = info[:ParentId]
        @description = info[:Description]
        @requires_authentication = info[:RequiresAuthentication]
        @allow_attachments = info[:AllowAttachments]
        @rank_order = info[:RankOrder]
        @topic_type = info[:TopicType]
        @display_name = info[:DisplayName]
        @contact_preferences = info[:ContactPreferences]
      end
    end
  end
end
