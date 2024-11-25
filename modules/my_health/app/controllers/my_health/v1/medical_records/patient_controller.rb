# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class PatientController < MrController
        # Gets a user's treatment facilities
        # @return [Array] of treatment facilities and related user info
        def index
          resource = bb_client.get_patient
          render json: resource.to_json
        end
      end
    end
  end
end
