# frozen_string_literal: true

class DrivetimeBand < ApplicationRecord
  belongs_to :vha_facility, class_name: 'Facilities::VHAFacility'

  class << self
    def find_within_max_distance(lat, lng, drive_time, ids)
      query = 'max <= :max AND ST_Intersects(polygon, ST_MakePoint(:lng,:lat))'
      params = { lng:, lat:, max: drive_time }

      if ids.present?
        query = "#{query} AND vha_facility_id IN (:ids)"
        params[:ids] = ids
      end

      DrivetimeBand.select(:name, :id, :vha_facility_id, :unit, :min, :max)
                   .where(query, params)
    end
  end
end
