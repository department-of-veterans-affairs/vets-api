# frozen_string_literal: true

# This serializer was used intended to be used in
# MyHealth::V1::MessagesController#signature
# However, it's not actually being used because the call doesn't
# follow JSON:API specs and just uses "object" itself

# I'm not deleting the serializer so the mhv team can update the
# controller and frontend at a later date.
module MyHealth
  module V1
    class MessageSignatureSerializer
      include JSONAPI::Serializer

      set_id { '' }

      attributes :signature_name do |object|
        object[:signature_name]
      end

      attributes :signature_title do |object|
        object[:signature_title]
      end

      attributes :include_signature do |object|
        signature_name = object[:signature_name]
        signature_title = object[:signature_title]
        signature_name.is_a?(String) && !signature_name.empty? &&
          signature_title.is_a?(String) && !signature_title.empty?
      end
    end
  end
end
