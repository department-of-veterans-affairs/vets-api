# frozen_string_literal: true

require 'common/models/form'
require 'common/models/attribute_types/httpdate'

module MHVAC
  class RegistrationForm < Common::Form
    include ActiveModel::Validations

    attribute :icn, String
    attribute :is_patient, Boolean
    attribute :is_patient_advocate, Boolean
    attribute :is_veteran, Boolean
    attribute :is_champ_VA_beneficiary, Boolean
    attribute :is_service_member, Boolean
    attribute :is_employee, Boolean
    attribute :is_health_care_provider, Boolean
    attribute :is_other, Boolean
    attribute :address1, String
    attribute :address2, String
    attribute :city, String
    attribute :state, String
    attribute :zip, String
    attribute :country, String
    attribute :province, String
    attribute :contact_method, String
    attribute :email, String
    attribute :fax, String
    attribute :home_phone, String
    attribute :mobile_phone, String
    attribute :pager, String
    attribute :work_phone, String
    attribute :sign_in_partners, String
    attribute :terms_version, String
    attribute :terms_accepted_date, Common::HTTPDate

    # NOTE: commenting out these validations because it's not entirely clear they're required
    # instead for now we're going to rely on MHV kicking back its error based on these.
    # validates :icn, :is_patient, :is_veteran, :email, presence: true
    # validates :address1, :city, :state, :zip, :country, presence: true
    # validates :sign_in_partners, :terms_version, :terms_accepted_date, presence: true

    def mhv_params
      raise Common::Exceptions::ValidationErrors, self unless valid?
      Hash[attribute_set.map do |attribute|
        value = send(attribute.name)
        [attribute.name, value] unless value.nil?
      end.compact]
    end
  end
end
