# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class AllergyIntolerance::Patient < Common::Resource
      attribute :reference, Types::String
      attribute :display, Types::String
    end
  end
end
