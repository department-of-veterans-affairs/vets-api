# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSerializer
    include JSONAPI::Serializer

    attributes :id, :claimant_id

    attribute :created_at do |object|
      object.created_at.iso8601
    end

    attribute :resolution do |object|
      next nil if object.resolution.blank?

      AccreditedRepresentativePortal::PowerOfAttorneyRequestResolutionSerializer.new(
        object.resolution
      ).serializable_hash[:data][:attributes]
    end
  end
end
