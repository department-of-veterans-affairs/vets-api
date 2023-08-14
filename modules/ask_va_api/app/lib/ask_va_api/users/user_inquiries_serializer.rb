# frozen_string_literal: true

module AskVAApi
  module Users
    class UserInquiriesSerializer < ActiveModel::Serializer
      include JSONAPI::Serializer
      set_type :user_inquiries

      attribute :inquiries do |object|
        object.inquiries.map do |inquiry|
          AskVAApi::Inquiries::Serializer.new(inquiry).serializable_hash
        end
      end
    end
  end
end
