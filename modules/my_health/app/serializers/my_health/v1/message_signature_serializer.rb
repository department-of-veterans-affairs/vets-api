# frozen_string_literal: true

module MyHealth
  module V1
    class MessageSignatureSerializer < ActiveModel::Serializer
      attributes :signature_name, :signature_title, :include_signature
    end
  end
end
