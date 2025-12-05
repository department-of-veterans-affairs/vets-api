# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class AvsPdf < Common::Resource
      attribute :appt_id, Types::String.optional
      attribute :id, Types::String.optional
      attribute :name, Types::String.optional
      attribute :loinc_codes, Types::Array.of(Types::String).optional
      attribute :note_type, Types::String.optional
      attribute :content_type, Types::String.optional
      attribute :binary, Types::String.optional
    end
  end
end
