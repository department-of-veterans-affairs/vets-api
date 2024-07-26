# frozen_string_literal: true

module MyHealth
  module V1
    class MessageSignatureSerializer
      include JSONAPI::Serializer

      set_id { '' }

      attributes :signature_name do |object|
        object[:data][:signature_name]
      end

      attributes :signature_title do |object|
        object[:data][:signature_title]
      end
      attributes :include_signature do |object|
        object[:data][:include_signature]
      end
    end
  end
end
