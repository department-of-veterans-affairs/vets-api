# frozen_string_literal: true

require 'dgi/fry_dea/service'

module MebApi
  module V0
    class FryDeaController < MebApi::V0::BaseController
      before_action :check_toe_flipper, only: [:sponsor]

      def sponsors
        render json: {
          data: {
            sponsors: [
              {
                firstName: 'Wilford',
                lastName: 'Brimley',
                sponsorRelationship: 'Spouse',
                dateOfBirth: '09/27/1934'
              }
            ],
            status: 201
          }
        }
      end

      private

      def fry_dea_service
        MebApi::DGI::FryDea::Sponsor::Service.new(@current_user)
      end
    end
  end
end
