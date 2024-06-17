# frozen_string_literal: true

class OktaAppSerializer < ActiveModel::Serializer
  attributes :id, :title, :logo, :privacy_url, :grants

  def read_attribute_for_serialization(attr)
    object[attr.to_s] || object['attributes'][attr.to_s]
  end
end
