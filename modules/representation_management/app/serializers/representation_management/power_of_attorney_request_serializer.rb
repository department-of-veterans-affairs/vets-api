# frozen_string_literal: true

module RepresentationManagement
  class PowerOfAttorneyRequestSerializer
    include JSONAPI::Serializer

    attributes :created_at, :expires_at
  end
end
