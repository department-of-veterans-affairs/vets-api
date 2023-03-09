# frozen_string_literal: true

module Mobile
  module V0
    class MessageSignatureSerializer
      include JSONAPI::Serializer

      set_type :messageSignature
      attributes :signature_name, :include_signature, :signature_title

      def initialize(id, signature_info, options = {})
        resource = MessageSignatureStruct.new(id,
                                              signature_info[:signature_name],
                                              signature_info[:include_signature],
                                              signature_info[:signature_title])
        super(resource, options)
      end
    end

    MessageSignatureStruct = Struct.new(:id, :signature_name, :include_signature, :signature_title)
  end
end
