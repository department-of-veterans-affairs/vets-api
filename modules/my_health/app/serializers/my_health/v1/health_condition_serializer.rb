# frozen_string_literal: true

module MyHealth
  module V1
    class HealthConditionSerializer
      include JSONAPI::Serializer

      attribute :id
      attribute :name
      attribute :date
      attribute :provider
      attribute :facility
      attribute :comments

      link :self do |object|
        MyHealth::UrlHelper.new.v1_condition_url(object.id)
      end
    end
  end
end
