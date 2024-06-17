# frozen_string_literal: true

class OktaAppSerializer < ActiveModel::Serializer
  attributes :id, :title, :logo, :privacy_url, :grants

  def grants
    object.grants.map do |grant|
      {
        title: grant['_links']['scope']['title'],
        id: grant['id'],
        created: grant['created']
      }
    end
  end

  def read_attribute_for_serialization(attr)
    object[attr.to_s] || object['attributes'][attr.to_s]
  end
end
