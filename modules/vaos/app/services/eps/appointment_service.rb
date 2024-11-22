# frozen_string_literal: true

module Eps
  class AppointmentService < BaseService
    ##
    # Get appointments data from EPS
    #
    # @return OpenStruct response from EPS appointments endpoint
    #
    def get_appointments(patient_id:)
      response = perform(:get, "/#{config.base_path}/appointments?patientId=#{patient_id}",
                         {}, headers)
      OpenStruct.new(response)
    end
  end
end
