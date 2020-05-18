class Lighthouse::Facilities::FacilitySerializer
  include FastJsonapi::ObjectSerializer

  attributes  :access,
              :active_status,
              :address,
              :classification,
              :facility_type,
              :feedback,
              :hours,
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
