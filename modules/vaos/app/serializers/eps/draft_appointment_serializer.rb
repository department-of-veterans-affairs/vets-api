# frozen_string_literal: true

module Eps
  class DraftAppointmentSerializer
    include JSONAPI::Serializer
    set_id :id

    attribute :provider do |object|
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
      object.slots.slots
    end

    attribute :drivetime do |object|
      {
        origin: object.drive_time.origin,
        destinations: object.drive_time.destinations
      }
    end
  end
end
