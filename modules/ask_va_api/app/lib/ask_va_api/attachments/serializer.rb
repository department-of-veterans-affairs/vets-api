# frozen_string_literal: true

module AskVAApi
  module Attachments
    class Serializer
      include JSONAPI::Serializer
      set_type :attachment

      attributes :file_content,
                 :file_name
    end
  end
end
