# frozen_string_literal: true

module AskVAApi
  module Profile
    class Serializer
      include JSONAPI::Serializer
      set_type :profile

      attributes :first_name, :middle_name, :last_name, :preferred_name, :suffix,
                 :gender, :pronouns, :country, :street, :city, :state, :zip_code,
                 :province, :business_phone, :personal_phone, :personal_email,
                 :business_email, :school_state, :school_facility_code, :service_number,
                 :claim_number, :veteran_service_start_date, :veteran_service_end_date,
                 :date_of_birth, :edipi
    end
  end
end
