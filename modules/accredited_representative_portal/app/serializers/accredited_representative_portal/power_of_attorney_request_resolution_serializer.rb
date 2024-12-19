# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestResolutionSerializer
    include JSONAPI::Serializer

    attribute :id

    attribute :type do |object|
      object.resolving_type.demodulize.underscore.split('_').last
    end

    attribute :decision_type, if: proc { |obj| obj.resolving.respond_to?(:type) } do |object|
      object.resolving.type
    end

    attribute :reason

    attribute :creator_id, if: proc { |obj| obj.resolving.respond_to?(:creator_id) } do |object|
      object.resolving.creator_id
    end

    attribute :created_at do |object|
      object.created_at.iso8601
    end
  end
end
