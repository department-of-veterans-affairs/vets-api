# frozen_string_literal: true

module Eps
  class ProviderService < BaseService
    ##
    # Get providers data from EPS
    #
    # @return OpenStruct response from EPS providers endpoint
    #
    def get_provider_services
      response = perform(:get, "/#{config.base_path}/provider-services",
                         {}, headers)
      OpenStruct.new(response.body)
    end

    ##
    # Get provider data from EPS
    #
    # @return OpenStruct response from EPS provider endpoint
    #
    def get_provider_service(provider_id:)
      response = perform(:get, "/#{config.base_path}/provider-services/#{provider_id}",
                         {}, headers)
      OpenStruct.new(response.body)
    end
  end
end
