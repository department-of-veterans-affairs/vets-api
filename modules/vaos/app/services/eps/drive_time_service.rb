# frozen_string_literal: true

module Eps
  class DriveTimeService < BaseService
    ##
    # Get drive time data from EPS
    #
    # @return OpenStruct response from EPS drive times endpoint
    #
    def get_drive_times

      # TODO: implement referrals call to CCRA, which will return
      # provider_id needed for below service call

      provider_data = provider_service.get_provider_service(provider_id:)

      destinations = {
        "12345-abcdef": {
          latitude: provider_data[:location][:latitude],
          longitude: provider_data[:location][:longitude]
        }
      }

      origin: {
        # TODO: verify user object attributes
        latitude: user.latitude,
        longitude: user.longitude
      }

      response = perform(:get, "/#{config.base_path}/drive-times",
                         { destinations: destinations, origin: origin }, headers)
      OpenStruct.new(response.body)
    end

    private

    def provider_service
      @provider_service ||= Eps::ProviderService.new(user)
    end
  end
end
