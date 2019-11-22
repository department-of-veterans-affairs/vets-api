# frozen_string_literal: true

require 'active_model'
require 'common/models/form'

module VAOS
  class AppointmentRequestForm < Common::Form
    attribute :email, String
    attribute :phone_number, String
    attribute :option_date1, String # TODO: ideally these would be better abstracted as an array for a FE consumer
    attribute :option_time1, String
    attribute :option_date2, String
    attribute :option_time2, String
    attribute :option_date3, String
    attribute :option_time3, String
    attribute :status, String
    attribute :appointment_type, String
    attribute :visit_type, String
    attribute :text_messaging_allowed, Boolean
    attribute :phone_number, String
    attribute :purpose_of_visit, String
    attribute :other_purpose_of_visit, String
    attribute :purpose_of_visit, String
    attribute :provider_id, String
    attribute :second_request, Boolean
    attribute :second_request_submitted, Boolean
    attribute :provider_name, String
    attribute :requested_phone_call, Boolean
    attribute :type_of_care_id, Boolean
    attribute :has_veteran_new_message, Boolean
    attribute :has_provider_new_message, Boolean
    attribute :provider_seen_appointment_request, Boolean
    attribute :requested_phone_call, Boolean
    attribute :type_of_care_id, String
    attribute :patient_id, String # This setter is overriden
    attribute :appointment_request_id, String # This setter is overriden
    attribute :unique_id, String # This setter is overriden
    attribute :id, String # This setter is overriden
    attribute :date, String # Automatically set for create if id is present; This setter is overridden
    attribute :created_date, VAOS::AppointmentTime # Only passed in when updating
    attribute :last_access_date, VAOS::AppointmentTime # Only passed in when updating
    attribute :last_updated_date, VAOS::AppointmentTime # Only passed in when updating
    attribute :assigning_authority, String, default: 'ICN'
    attribute :system_id, String, default: 'var'
    attribute :object_type, String, default: 'VARAppointmentRequest'
    attribute :surrogate_identifier, Hash, default: {}
    attribute :facility, Hash
    attribute :patient, Hash, default: { inpatient: false, text_messaging_allowed: false } # This setter is overriden
    attribute :best_timeto_call, Array[String] # VAR camel cases this incorrectly so we will snakecase it incorrectly
    attribute :appointment_request_detail_code, Array[String] # This setter is overriden

    def initialize(user, json_hash)
      @user = user
      @id = json_hash[:id]
      @appointment_request_id = @id # ensure these are the same (and the FE doesn't have to pass in redundant data)
      @unique_id = @id # ensure these are the same (and the FE doesn't have to pass in redundant data)
      @date = Time.current.strftime('%Y-%m-%dT%H:%M:%S.%L%z') if @id.blank? # only set for create in proper format
      @patient_id = edipi # TODO: discover if the patient_id ever comes from elsewhere or if it is always EDIPI
      super(json_hash)
    end

    # Ensure that these cannot be mass assigned or modified after initialization
    def id=(_value); end

    def appointment_request_id=(_value); end

    def unique_id=(_value); end

    def date=(_value); end

    def patient_id=(_value); end

    # These values are provided directly from FE without coercion; we may need to validate some of these
    def facility=(values_hash)
      @facility = values_hash.empty? ? {} : values_hash.merge(object_type: 'Facility').compact
    end

    # These values ought to be derived from MVI vs user input, except for inpatient and text_messaging_allowed
    def patient=(values_hash)
      @patient = {
        display_name: "#{last_name}, #{first_name}",
        first_name: first_name,
        last_name: last_name,
        date_of_birth: dob,
        patient_identifier: {
          unique_id: edipi
        },
        ssn: ssn,
        inpatient: values_hash[:inpatient],
        text_messaging_allowed: values_hash[:text_messaging_allowed],
        id: edipi,
        object_type: 'Patient'
      }.compact
    end

    # The incoming appointment request detail code could be nil, could include an array of codes only, or it could
    # be the array of hashes below.
    def appointment_request_detail_code=(values)
      @appointment_request_detail_code = if values&.first.is_a?(String)
                                           Array.wrap(values).map do |code|
                                             {
                                               user_id: @user.icn,
                                               detail_code: { code: code }
                                             }
                                           end
                                         else
                                           values
                                         end
    end

    def params
      # TODO: FE to do discovery on possible validations we might add.
      raise Common::Exceptions::ValidationErrors, self unless valid?

      params = attributes.compact
      put_request? ? params.merge(patient_identifier: patient_identifier) : params
    end

    private

    def put_request?
      @id.present?
    end

    # Only needed for updates
    def patient_identifier
      {
        assigning_authority: 'ICN',
        patient_identifier: @user.icn
      }
    end

    def first_name
      @user.mvi&.profile&.given_names&.first
    end

    def last_name
      @user.mvi&.profile&.family_name
    end

    def dob
      Date.parse(@user.mvi.profile.birth_date).strftime('%b %d, %Y')
    rescue
      ''
    end

    def edipi
      @user.mvi&.profile&.edipi
    end

    def ssn
      @user.mvi&.profile&.ssn
    end
  end
end
