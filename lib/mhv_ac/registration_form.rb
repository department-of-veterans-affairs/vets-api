# frozen_string_literal: true
require 'common/models/form'

module MHVAC
  class RegistrationForm < Common::Form
    attribute :icn, String
    attribute :is_patient, Boolean
    attribute :is_patient_advocate, Boolean
    attribute :is_veteran, Boolean
    attribute :is_champ_VA_beneficiary, Boolean
    attribute :is_service_member, Boolean
    attribute :is_employee, Boolean
    attribute :is_health_care_provider, Boolean
    attribute :is_other, Boolean
    attribute :city, String
    attribute :country, String
    attribute :zip, String
    attribute :province, String
    attribute :state, String
    attribute :address1, String
    attribute :address2, String
    attribute :contact_method, String
    attribute :email, String
    attribute :fax, String
    attribute :home_phone, String
    attribute :mobile_phone, String
    attribute :pager, String
    attribute :work_phone, String
    attribute :sign_in_partners, String
    attribute :terms_version, String
    attribute :terms_accepted_date, String

    # TODO: the above attrs will be camelcased by middleware
    def params
      { }
    end
  end
end
