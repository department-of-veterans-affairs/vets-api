# frozen_string_literal: true

module FacilitiesQuery
  class IdsQuery < Base
    def run
      ids_for_types(params[:ids]).flat_map do |facility_type, unique_ids|
        klass = "Facilities::#{facility_type.upcase}Facility".constantize
        klass.where(unique_id: unique_ids)
      end
    end

    def ids_for_types(ids)
      ids.split(',').each_with_object(Hash.new { |h, k| h[k] = [] }) do |type_id, obj|
        facility_type, unique_id = type_id.split('_')
        obj[facility_type].push unique_id if facility_type && unique_id
      end
    end
  end
end
