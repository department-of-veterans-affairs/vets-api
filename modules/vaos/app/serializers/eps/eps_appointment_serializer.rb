# frozen_string_literal: true

module Eps
  class EpsAppointmentSerializer
    include JSONAPI::Serializer

    set_key_transform :camel_lower
    attribute :id, &:id

    attribute :status, &:status

    attribute :start, &:start

    attribute :is_latest, &:is_latest

    attribute :last_retrieved, &:last_retrieved

    attribute :modality, &:modality

    attribute :provider, &:provider_details

    attribute :past, &:past

    attribute :referral_id, &:referral_id

    attribute :location do |object|
      location_data = object.location
      location_data.presence
    end
  end
end
