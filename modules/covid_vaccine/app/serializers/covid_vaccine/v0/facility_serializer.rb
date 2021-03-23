# frozen_string_literal: true

module CovidVaccine
  module V0
    class FacilitySerializer
      include FastJsonapi::ObjectSerializer

      attribute(:name) { |x| x[:name] }
      attribute(:distance) { |x| x[:distance] }
      attribute(:city) { |x| x[:city] }
      attribute(:state) { |x| x[:state] }

      set_type :suggested_facility

      set_id { |x| x[:id] }
      def id
        object[:id]
      end

      def type
        'vaccination_facility'
      end
    end
  end
end
