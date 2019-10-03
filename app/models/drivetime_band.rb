# frozen_string_literal: true

class DrivetimeBand < ApplicationRecord
  belongs_to :vha_facility, class_name: 'Facilities::VHAFacility'
end
