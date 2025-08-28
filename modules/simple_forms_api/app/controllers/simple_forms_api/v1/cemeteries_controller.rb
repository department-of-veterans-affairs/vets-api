# frozen_string_literal: true

module SimpleFormsApi
  module V1
    class CemeteriesController < ApplicationController
      skip_before_action :authenticate, only: [:index]
      
      def index
        cemeteries = SimpleFormsApi::CemeteryService.all

        render json: {
          data: cemeteries.map { |cemetery| format_cemetery(cemetery) }
        }
      end

      private

      def format_cemetery(cemetery_data)
        {
          id: cemetery_data['id'],
          type: cemetery_data['type'],
          attributes: {
            cemetery_id: cemetery_data['attributes']['cemetery_id'],
            name: cemetery_data['attributes']['name'],
            cemetery_type: cemetery_data['attributes']['cemetery_type'],
            num: cemetery_data['attributes']['num']
          }
        }
      end
    end
  end
end