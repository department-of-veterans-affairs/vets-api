# frozen_string_literal: true

module FacilitiesQuery
  class IdsQuery < Base
    def run
      ids_for_types(params[:ids]).flat_map do |facility_type, unique_ids|
        klass = "Facilities::#{facility_type.upcase}Facility".constantize
        klass.where(unique_id: unique_ids)
      end
    end
  end
end
