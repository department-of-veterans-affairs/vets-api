# frozen_string_literal: true

module Eps
  class EpsAppointmentSerializer
    include JSONAPI::Serializer

    attribute :id do |object|
      object.appointment[:id]
    end

    attribute :status do |object|
      object.appointment[:status]
    end

    attribute :start do |object|
      object.appointment[:start]
    end

    attribute :type_of_care do |object|
      object.referral_detail&.category_of_care
    end

    attribute :is_latest do |object|
      object.appointment[:is_latest]
    end

    attribute :last_retrieved do |object|
      object.appointment[:last_retrieved]
    end

    attribute :modality do |_object|
      # NOTE: this is intentionally hardcoded for now for prototype,
      # will be updated once confirmed that the data will be available
      # from the referral object
      'OV'
    end

    attribute :provider do |object|
      next if object.provider.nil?

      {
        id: object.provider.id,
        name: object.provider.name,
        is_active: object.provider.is_active,
        organization: object.provider.provider_organization,
        location: object.provider.location,
        network_ids: object.provider.network_ids,
        phone_number: object.referral_detail&.phone_number
      }.compact
    end
  end
end
