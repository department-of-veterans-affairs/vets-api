# frozen_string_literal: true

module SignIn
  class UserInfoSerializer
    include JSONAPI::Serializer

    attribute :csp_type, :csp_uuid, :ial, :aal, :email, :full_name, :birth_date,
              :ssn, :gender, :address, :phone_number, :person_type, :icn,
              :sec_id, :edipi, :mhv_ien, :cerner_id, :corp_id, :birls
  end
end
