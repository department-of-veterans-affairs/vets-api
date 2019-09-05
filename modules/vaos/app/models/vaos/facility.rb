# frozen_string_literal: true

require 'common/models/resource'

module VAOS
  class Facility < Common::Resource
    attribute :id, Types::String
    attribute :name, Types::String
    attribute :type, Types::String
    attribute :address, Types::String
    attribute :city, Types::String
    attribute :state, Types::String
    attribute :direct_schedule_enabled, Types::Bool
    attribute :parent_site_code, Types::Integer
  end
end
