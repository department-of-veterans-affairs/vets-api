module LoadTesting
  module V0
    class ConfigController < ApplicationController
      def show
        render json: {
          api_base_url: LoadTesting.configuration.api_base_url,
          client_id: params[:client_id] || 'load_test_client',
          type: params[:type] || 'logingov',
          acr: params[:acr] || 'http://idmanagement.gov/ns/assurance/ial/2'
        }
      end
    end
  end
end 