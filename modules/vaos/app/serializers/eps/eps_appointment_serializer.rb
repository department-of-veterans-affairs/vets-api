# frozen_string_literal: true

module Eps
  class EpsAppointmentSerializer
    include JSONAPI::Serializer

    attribute :id, &:id

    attribute :status, &:status

    attribute :start, &:start

    attribute :type_of_care, &:type_of_care

    attribute :is_latest, &:is_latest

    attribute :last_retrieved, &:last_retrieved

    attribute :modality do |_object|
      # NOTE: this is intentionally hardcoded for now for prototype,
      # will be updated once confirmed that the data will be available
      # from the referral object
      'OV'
    end

    attribute :provider, &:provider_details

    attribute :referring_facility, &:referring_facility_details
  end
end
