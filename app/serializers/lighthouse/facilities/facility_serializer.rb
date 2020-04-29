class Lighthouse::Facilities::FacilitySerializer < ActiveModel::Serializer
  type 'facilities'

  attributes  :access,
              :address,
              :classification,
              :facility_type,
              :feedback,
              :hours,
              :lat,
              :long,
              :name,
              :operating_status,
              :phone,
              :services,
              :unique_id,
              :visn,
              :website
end
