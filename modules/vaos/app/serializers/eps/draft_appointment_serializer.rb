# frozen_string_literal: true

module Eps
  class DraftAppointmentSerializer
    include JSONAPI::Serializer

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
        features: object.provider.features
      }
    end

    attribute :slots do |object|
      object.slots&.slots
    end

    attribute :drivetime do |object|
      next if object.drive_time.nil?

      {
        origin: object.drive_time.origin,
        destination: object.drive_time.destinations&.values&.first
      }
    end
  end
end
