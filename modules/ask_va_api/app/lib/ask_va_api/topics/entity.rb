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
        @id = info[:id]
        @name = info[:name]
        @parent_id = info[:parentId]
        @description = info[:description]
        @requires_authentication = info[:requiresAuthentication]
        @allow_attachments = info[:allowAttachments]
        @rank_order = info[:rankOrder]
        @display_name = info[:displayName]
      end
    end
  end
end
