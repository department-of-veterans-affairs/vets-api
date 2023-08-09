# frozen_string_literal: true

class UserInquiriesSerializer < ActiveModel::Serializer
  include JSONAPI::Serializer

  set_type :user_inquiries

  attribute :inquiries do |object|
    object.inquiries.map do |inquiry|
      InquirySerializer.new(inquiry).serializable_hash
    end
  end

  def read_attribute_for_serialization(attr)
    respond_to?(attr) ? send(attr) : object[attr]
  end
end
