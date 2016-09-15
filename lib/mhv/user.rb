# frozen_string_literal: true
require 'common/models/base'
require 'common/models/attribute_types/utc_time'
module MHV
  # User model
  class NewUserForm < Common::Base
    extend ActiveModel::Callbacks
    include ActiveModel::Validations
    define_model_callbacks :initialize, only: :after

    attribute :form_token

    attribute :title
    attribute :first_name
    attribute :middle_name
    attribute :last_name
    attribute :suffix
    attribute :alias
    attribute :ssn1
    attribute :ssn2
    attribute :ssn3
    attribute :verify_ssn1
    attribute :verify_ssn2
    attribute :verify_ssn3
    attribute :gender
    attribute :birth_month
    attribute :birth_day
    attribute :birth_year
    attribute :marital_status

    attribute :is_patient
    attribute :is_patient_advocate
    attribute :is_veteran
    attribute :is_employee
    attribute :is_healthcare_provider
    attribute :is_other

    attribute :blood_type
    attribute :is_organ_donor

    attribute :country
    attribute :street1
    attribute :street2
    attribute :city
    attribute :state
    attribute :zip
    attribute :province

    attribute :contact_method
    attribute :email
    attribute :email_confirmation
    attribute :home_phone
    attribute :mobile_phone
    attribute :work_phone
    attribute :fax
    attribute :pager

    attribute :rx_tracking_email_preference
    attribute :appointment_email_preference

    attribute :username
    attribute :password
    attribute :password_confirmation

    attribute :password_hint_question1
    attribute :password_hint_answer1
    attribute :password_hint_question2
    attribute :password_hint_answer2

    attribute :accept_terms
    attribute :accept_privacy_terms
    attribute :accept_secure_messaging_terms

    # Add additional validations here
    validates :token, presence: true

    MHV_ATTRIBUTE_KEY_MAPPINGS = {
      form_token: 'userRegistrationPortletorg.apache.struts.taglib.html.TOKEN',
      title: 'userRegistrationPortletwlw-select_key:{actionForm.userProfileTitle}',
      first_name: 'userRegistrationPortlet{actionForm.userProfileFirstName}',
      middle_name: 'userRegistrationPortlet{actionForm.userProfileMiddleName}',
      last_name: 'userRegistrationPortlet{actionForm.userProfileLastName}',
      suffix: 'userRegistrationPortletwlw-select_key:{actionForm.userProfileSuffix}',
      alias: 'userRegistrationPortlet{actionForm.userProfileUserAlias}',
      ssn1: 'userRegistrationPortlet{actionForm.ssn1}',
      ssn2: 'userRegistrationPortlet{actionForm.ssn2}',
      ssn3: 'userRegistrationPortlet{actionForm.ssn3}',
      verify_ssn1: 'userRegistrationPortlet{actionForm.verifySsn1}',
      verify_ssn2: 'userRegistrationPortlet{actionForm.verifySsn2}',
      verify_ssn3: 'userRegistrationPortlet{actionForm.verifySsn3}',
      gender: 'userRegistrationPortletwlw-select_key:{actionForm.userProfileGender}',
      birth_month: 'userRegistrationPortletwlw-select_key:{actionForm.userProfileBirthDateMonth}',
      birth_day: 'userRegistrationPortletwlw-select_key:{actionForm.userProfileBirthDateDay}',
      birth_year: 'userRegistrationPortletwlw-select_key:{actionForm.userProfileBirthDateYear}',
      marital_status: 'userRegistrationPortletwlw-select_key:{actionForm.userProfileMaritalStatus}',
      occupation: 'userRegistrationPortlet{actionForm.userProfileCurrentOccupation}',
      blood_type: 'userRegistrationPortletwlw-select_key:{actionForm.userProfileBloodType}',
      country: 'userRegistrationPortletwlw-select_key:{actionForm.userProfileAddressCountry}',
      street1: 'userRegistrationPortlet{actionForm.userProfileAddressStreet1}',
      street2: 'userRegistrationPortlet{actionForm.userProfileAddressStreet2}',
      city: 'userRegistrationPortlet{actionForm.userProfileAddressCity}',
      state: 'userRegistrationPortletwlw-select_key:{actionForm.userProfileAddressState}',
      zip: 'userRegistrationPortlet{actionForm.userProfileAddressPostalCode}',
      province: 'userRegistrationPortlet{actionForm.userProfileAddressProvince}',
      contact_method: 'userRegistrationPortletwlw-select_key:{actionForm.userProfileContactInfoContactMethod}',
      email: 'userRegistrationPortlet{actionForm.userProfileContactInfoEmail}',
      email_confirmation: 'userRegistrationPortlet{actionForm.reenterContactInfoEmail}',
      home_phone: 'userRegistrationPortlet{actionForm.userProfileContactInfoHomePhone}',
      mobile_phone: 'userRegistrationPortlet{actionForm.userProfileContactInfoMobilePhone}',
      work_phone: 'userRegistrationPortlet{actionForm.userProfileContactInfoWorkPhone}',
      fax: 'userRegistrationPortlet{actionForm.userProfileContactInfoFax}',
      pager: 'userRegistrationPortlet{actionForm.userProfileContactInfoPager}',
      rx_tracking_email_preference: 'userRegistrationPortletwlw-radio_button_group_key:{actionForm.userProfileRxTrackingEmailPref}',
      appointment_email_preference: 'userRegistrationPortletwlw-radio_button_group_key:{actionForm.userProfileApptEmailPref}',
      username: 'userRegistrationPortlet{actionForm.userName}',
      password: 'userRegistrationPortlet{actionForm.password}',
      password_confirmation: 'userRegistrationPortlet{actionForm.confirmPassword}',
      password_hint_question1: 'userRegistrationPortletwlw-select_key:{actionForm.userProfilePasswordHintQuestion1}',
      password_hint_answer1: 'userRegistrationPortlet{actionForm.userProfilePasswordHintAnswer1}',
      password_hint_question2: 'userRegistrationPortletwlw-select_key:{actionForm.userProfilePasswordHintQuestion2}',
      password_hint_answer2: 'userRegistrationPortlet{actionForm.userProfilePasswordHintAnswer2}',
    }.freeze

    def mhv_attributes
      attributes.map {|k, v| [MHV_ATTRIBUTE_KEY_MAPPINGS[k], v] }.to_h
    end
  end
end
