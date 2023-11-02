# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class DiagnosticReport < Common::Resource
      attribute :id, Types::String
      attribute :category, Types::String
      attribute :code, Types::String
      attribute :subject, Types::String
      attribute :effectiveDateTime, Types::DateTime
      attribute :issued, Types::DateTime
      attribute :result, Types::Array
    end
  end
end
