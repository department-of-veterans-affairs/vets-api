# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class MrSessionController < MRController
        def create
          client
          head :no_content
        end

        def status
          resource = phrmgr_client.get_phrmgr_status
          render json: resource.to_json
        end
      end
    end
  end
end
