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

    attribute :modality do |_object|
      # NOTE: this is intentionally hardcoded for now for prototype,
      # will be updated once confirmed that the data will be available
      # from the referral object
      'OV'
    end

    attribute :provider, &:provider_details

    attribute :referring_facility do |_object|
      {}
    end
  end
end
