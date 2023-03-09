# frozen_string_literal: true

module VAOS
  module V2
    class FacilitiesSerializer
      include JSONAPI::Serializer

      set_id :id

      set_type :facilities

      attributes :id,
                 :vista_site,
                 :vast_parent,
                 :type,
                 :name,
                 :classification,
                 :timezone,
                 :lat,
                 :long,
                 :website,
                 :phone,
                 :hours_of_operation,
                 :mailing_address,
                 :physical_address,
                 :mobile,
                 :health_service,
                 :operating_status
    end
  end
end
