# frozen_string_literal: true

module AskVAApi
  module Categories
    class Serializer
      include JSONAPI::Serializer
      set_type :categories

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
