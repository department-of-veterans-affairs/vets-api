# frozen_string_literal: true

module AskVAApi
  module Topics
    class Entity
      attr_reader :id,
                  :name,
                  :parent_id,
                  :description,
                  :requires_authentication,
                  :allow_attachments,
                  :rank_order,
                  :display_name

      def initialize(info)
        @id = info[:Id]
        @name = info[:Name]
        @parent_id = info[:ParentId]
        @description = info[:Description]
        @requires_authentication = info[:RequiresAuthentication]
        @allow_attachments = info[:AllowAttachments]
        @rank_order = info[:RankOrder]
        @display_name = info[:DisplayName]
      end
    end
  end
end
