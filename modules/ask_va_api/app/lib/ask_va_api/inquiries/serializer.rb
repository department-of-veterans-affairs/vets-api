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

      attribute :reply do |obj|
        AskVAApi::Replies::Serializer.new(obj.reply).serializable_hash
      end
    end
  end
end
