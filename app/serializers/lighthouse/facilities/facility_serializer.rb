class Lighthouse::Facilities::FacilitySerializer
  include FastJsonapi::ObjectSerializer

  attributes  :access,
              :address,
              :classification,
              :facility_type,
              :feedback,
              :hours,
              :lat,
              :long,
              :name,
              :operating_notes,
              :operating_status,
              :phone,
              :services,
              :unique_id,
              :website
end
