# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class AllergyIntolerance::ClinicalStatus < Common::Resource
      class Coding < Common::Resource
        attribute :system, Types::String
        attribute :code, Types::String
      end

      attribute :coding, Types::Array.of(Coding)
    end
  end
end
