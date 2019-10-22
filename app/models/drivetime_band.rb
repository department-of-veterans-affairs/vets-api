# frozen_string_literal: true

class DrivetimeBand < ApplicationRecord
  belongs_to :vha_facility, class_name: 'Facilities::VHAFacility'

  class << self
    def find_within_max_distance(lat, lng, drive_time)
      DrivetimeBand.select(:name, :id, :vha_facility_id, :unit, :min, :max)
                   .where('ST_Intersects(polygon, ST_MakePoint(:lng,:lat)) AND max <= :max',
                          lng: lng,
                          lat: lat,
                          max: drive_time)
    end
  end
end
