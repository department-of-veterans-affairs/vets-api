# frozen_string_literal: true

module Eps
  class DraftAppointmentSerializer
    include JSONAPI::Serializer

    attribute :provider do |object|
      next if object.provider.nil?

      {
        id: object.provider.id,
        name: object.provider.name,
        isActive: object.provider.isActive,
        individualProviders: object.provider.individualProviders,
        providerOrganization: object.provider.providerOrganization,
        location: object.provider.location,
        networkIds: object.provider.networkIds,
        schedulingNotes: object.provider.schedulingNotes,
        appointmentTypes: object.provider.appointmentTypes,
        specialties: object.provider.specialties,
        visitMode: object.provider.visitMode,
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
