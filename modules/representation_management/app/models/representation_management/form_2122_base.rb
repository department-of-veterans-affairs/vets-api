module RepresentationManagement
  class Form2122Base
    include ActiveModel::Model

    veteran_attrs = %i[
      veteran_first_name veteran_middle_initial veteran_last_name
      veteran_social_security_number
      veteran_file_number
      veteran_address_line1
      veteran_address_line2
      veteran_city
      veteran_country
      veteran_state_code
      veteran_zip_code
      veteran_zip_code_suffix
      veteran_area_code
      veteran_phone_number
      veteran_phone_number_ext
      veteran_email
      veteran_service_number
      veteran_insurance_number
    ]

    claimant_attrs = %i[
      claimant_first_name
      claimant_middle_initial
      claimant_last_name
      claimant_address_line1
      claimant_address_line2
      claimant_city
      claimant_country
      claimant_state_code
      claimant_zip_code
      claimant_zip_code_suffix
      claimant_area_code
      claimant_phone_number
      claimant_phone_number_ext
      claimant_email
      claimant_relationship
    ]

    attr_accessor [veteran_attrs, claimant_attrs, service_organization_attrs].flatten
  end
end
