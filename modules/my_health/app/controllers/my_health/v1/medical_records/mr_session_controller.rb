# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class MrSessionController < MrController
        def create
          client
          head :no_content
        rescue ::MedicalRecords::PatientNotFound
          render body: nil, status: :accepted
        end

        def status
          resource = phrmgr_client.get_phrmgr_status
          render json: resource.to_json
        rescue ::MedicalRecords::PatientNotFound
          render body: nil, status: :accepted
        end
      end
    end
  end
end
