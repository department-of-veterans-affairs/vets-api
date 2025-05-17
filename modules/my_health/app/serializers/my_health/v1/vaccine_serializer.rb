# frozen_string_literal: true

module MyHealth
  module V1
    class VaccineSerializer
      include JSONAPI::Serializer

      attribute :id
      attribute :name
      attribute :date_received
      attribute :location
      attribute :manufacturer
      attribute :reactions
      attribute :notes

      link :self do |object|
        MyHealth::UrlHelper.new.v1_vaccine_url(object.id)
      end
    end
  end
end
