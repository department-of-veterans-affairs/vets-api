# frozen_string_literal: true

module CovidVaccine
  module V0
    class FacilitySerializer
      include JSONAPI::Serializer

      attribute(:name) { |x| x[:name] }
      attribute(:distance) { |x| x[:distance] }
      attribute(:city) { |x| x[:city] }
      attribute(:state) { |x| x[:state] }

      set_type :vaccination_facility

      set_id { |x| x[:id] }
    end
  end
end
