# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class MedicalService < Common::Resource
      attribute :name, Types::String
      attribute :request_eligible_facilities, Types::Array
      attribute :direct_eligible_facilities, Types::Array
    end
  end
end
