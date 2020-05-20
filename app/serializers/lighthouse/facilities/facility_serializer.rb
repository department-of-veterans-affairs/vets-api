# frozen_string_literal: true

class Lighthouse::Facilities::FacilitySerializer
  include FastJsonapi::ObjectSerializer

  attributes  :access,
              :active_status,
              :address,
              :classification,
              :facility_type,
              :feedback,
              :hours,
              :id,
              :lat,
              :long,
              :mobile,
              :name,
              :operating_status,
              :phone,
              :services,
              :unique_id,
              :visn,
              :website
end
