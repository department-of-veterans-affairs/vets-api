# frozen_string_literal: true
require 'common/models/form'

module MHVAC
  class RegistrationForm < Common::Form
    # TODO: Probably need to get some clarity on what some of these are
    attribute :icn, String
    attribute :is_patient, Boolean, default: true
    attribute :is_patient_advocate, Boolean, default: false
    attribute :is_veteran, Boolean, default: true
    attribute :is_champ_VA_beneficiary, Boolean, default: false
    attribute :is_service_member, Boolean, default: false
    attribute :is_employee, Boolean, default: false
    attribute :is_health_care_provider, Boolean, default: false
    attribute :is_other, Boolean, default: false
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
    attribute :sign_in_partners, String, default: 'VETS.GOV'
    attribute :terms_version, String, default: 'v3.2'
    attribute :terms_accepted_date, String

    # TODO: the above attrs will be camelcased by middleware
    def params
      Hash[attribute_set.map do |attribute|
        value = send(attribute.name)
        [attribute.name, value] unless value.nil?
      end.compact]
    end

    def self.from_user(_user)
    end
  end
end
