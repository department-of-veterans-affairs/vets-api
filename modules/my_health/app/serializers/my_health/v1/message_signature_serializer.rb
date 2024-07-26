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
