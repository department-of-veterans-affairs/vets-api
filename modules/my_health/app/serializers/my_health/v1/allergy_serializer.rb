# frozen_string_literal: true

module MyHealth
  module V1
    class AllergySerializer
      include JSONAPI::Serializer

      attribute :id
      attribute :name
      attribute :date
      attribute :categories
      attribute :reactions
      attribute :location
      attribute :observedHistoric, String # 'o' or 'h'
      attribute :notes
      attribute :provider

      link :self do |object|
        MyHealth::UrlHelper.new.v1_allergy_url(object.id)
      end
    end
  end
end
