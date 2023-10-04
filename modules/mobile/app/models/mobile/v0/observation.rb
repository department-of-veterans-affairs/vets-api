# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class Observation < Common::Resource
      attribute :id, Types::String
      attribute :status, Types::String
      attribute :category, Types::Hash
      attribute :code, Types::Hash
      attribute :subject, Types::Hash
      attribute :effectiveDateTime, Types::DateTime
      attribute :issued, Types::DateTime
      attribute :performer, Types::Hash
      attribute :valueQuantity, Types::Hash
    end
  end
end
