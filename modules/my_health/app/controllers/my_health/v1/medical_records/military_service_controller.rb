# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class MilitaryServiceController < MrController
<<<<<<< HEAD
        # Gets a user's military service record
        # @return [String] military service record in text format
        def index
          resource = phrmgr_client.get_military_service(@current_user.edipi)
          render json: resource.to_json
=======
        class MissingEdipiError < StandardError; end

        ##
        # Get a user's military service record
        #
        # @return [String] military service record in text format
        #
        def index
          raise MissingEdipiError, 'No EDIPI found for the current user' if @current_user.edipi.blank?

          resource = phrmgr_client.get_military_service(@current_user.edipi)
          render json: resource.to_json
        rescue MissingEdipiError => e
          render json: { error: e }, status: :bad_request
>>>>>>> ef3c0288176bba86adfb7abaf6e3a2c9bd88c1aa
        end
      end
    end
  end
end
