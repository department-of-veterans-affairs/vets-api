# frozen_string_literal: true

module Eps
  class EpsAppointmentSerializer
    include JSONAPI::Serializer

    attribute :appointment do |object|
      next if object.appointment.nil?

      VAOS::V2::EpsAppointment.new(object.appointment).serializable_hash
    end

    attribute :provider do |object|
      next if object.provider.nil?

      {
        id: object.provider.id,
        name: object.provider.name,
        is_active: object.provider.is_active,
        individual_providers: object.provider.individual_providers,
        provider_organization: object.provider.provider_organization,
        location: object.provider.location,
        network_ids: object.provider.network_ids,
        scheduling_notes: object.provider.scheduling_notes,
        appointment_types: object.provider.appointment_types,
        specialties: object.provider.specialties,
        visit_mode: object.provider.visit_mode,
        features: object.provider.features,
        phone_number: object.provider.phone_number
      }.compact
    end
  end
end
