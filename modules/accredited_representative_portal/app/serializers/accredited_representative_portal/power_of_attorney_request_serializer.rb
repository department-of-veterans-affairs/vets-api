# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSerializer
    include JSONAPI::Serializer

    attributes :id, :claimant_id

    attribute :created_at do |object|
      object.created_at.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
    end

    attribute :resolution do |object|
      next nil unless object.resolution

      {
        id: object.resolution.id,
        type: object.resolution.resolving_type&.demodulize&.underscore,
        created_at: object.resolution.created_at.strftime('%Y-%m-%dT%H:%M:%S.%LZ'),
        reason: object.resolution&.reason,
        creator_id: object.resolution.resolving.try(:creator_id)
      }.compact
    end
  end
end
