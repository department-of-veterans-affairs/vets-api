# frozen_string_literal: true

class InquirySerializer < ActiveModel::Serializer
  include JSONAPI::Serializer
  attributes :inquiry_number,
             :topic,
             :question,
             :processing_status,
             :last_update

  def read_attribute_for_serialization(attr)
    respond_to?(attr) ? send(attr) : object[attr]
  end
end
