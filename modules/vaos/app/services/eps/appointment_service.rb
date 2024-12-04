# frozen_string_literal: true

module Eps
  class AppointmentService < BaseService
    ##
    # Get appointments data from EPS
    #
    # @return OpenStruct response from EPS appointments endpoint
    #
    def get_appointments
      response = perform(:get, "/#{config.base_path}/appointments?patientId=#{patient_id}",
                         {}, headers)
      OpenStruct.new(response.body)
    end

    ##
    # Create draft appointment in EPS
    #
    # @return OpenStruct response from EPS create draft appointment endpoint
    #
    def create_draft_appointment(patient_id:, referral_id:)
      response = perform(:post, "/#{config.base_path}/appointments",
                         { patientId: patient_id, referralId: referral_id }, headers)
      OpenStruct.new(response.body)
    end
  end
end
