# frozen_string_literal: true

module AskVAApi
  module SubTopics
    class Serializer
      include JSONAPI::Serializer
      set_type :sub_topics

      attributes :name,
                 :allow_attachments,
                 :description,
                 :display_name,
                 :parent_id,
                 :rank_order,
                 :requires_authentication
    end
  end
end
