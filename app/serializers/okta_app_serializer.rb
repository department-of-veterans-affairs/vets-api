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
end
