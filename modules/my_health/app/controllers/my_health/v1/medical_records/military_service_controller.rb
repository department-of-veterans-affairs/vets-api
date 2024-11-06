# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class MilitaryServiceController < MrController
        # Gets a user's military service record
        # @return [String] military service record in text format
        def index
          resource = phrmgr_client.get_military_service(@current_user.edipi)
          render json: resource.to_json
        end
      end
    end
  end
end
