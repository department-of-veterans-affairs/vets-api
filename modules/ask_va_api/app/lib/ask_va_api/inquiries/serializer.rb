# frozen_string_literal: true

module AskVAApi
  module Inquiries
    class Serializer < ActiveModel::Serializer
      include JSONAPI::Serializer
      set_type :inquiry

      attributes :attachments,
                 :inquiry_number,
                 :topic,
                 :question,
                 :processing_status,
                 :last_update

      def read_attribute_for_serialization(attr)
        respond_to?(attr) ? send(attr) : object[attr]
      end
    end
  end
end
