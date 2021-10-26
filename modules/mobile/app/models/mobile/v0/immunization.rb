# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class Immunization < Common::Resource
      attribute :id, Types::String
      attribute :cvx_code, Types::Coercible::Integer
      attribute :date, Types::DateTime
      attribute :dose_number, Types::String.optional
      attribute :dose_series, Types::String.optional
      attribute :group_name, Types::String.optional
      attribute :manufacturer, Types::String.optional
      attribute :note, Types::String.optional
      attribute :short_description, Types::String.optional
    end
  end
end
