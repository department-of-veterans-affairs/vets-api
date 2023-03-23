# frozen_string_literal: true

module Mobile
  module V0
    module LighthouseHealth
      # Service that connects to VA Lighthouse's Veteran Health FHIR API
      # https://developer.va.gov/explore/health/docs/fhir?version=current
      #
      class Service < Common::Client::Base
        configuration Configuration

        # @param user IAMUser the user requesting the records
        #
        def initialize(user)
          @user = user
        end

        # Performs a query for a list of immunizations for a veteran
        # by ICN (identified in the access token)
        #
        # @return Hash the list of immunizations decoded from JSON
        #
        def get_immunizations
          response = perform(:get, 'Immunization', params, headers)
          response.body
        end

        # Performs a query location info
        # by id
        #
        # @return Hash of location info based on id provided
        #
        def get_location(id)
          response = perform(:get, "Location/#{id}", nil, headers)
          Rails.logger.info('Mobile Lighthouse Service, Location response', response:)
          raise Common::Exceptions::BackendServiceException, 'LIGHTHOUSE_FACILITIES404' if response[:status] == 404

          response.body
        end

        private

        def headers
          config.base_request_headers.merge(Authorization: "Bearer #{access_token}")
        end

        def params
          { patient: @user.icn }
        end

        def access_token
          cached_session = LighthouseSession.get_cached(@user)
          return cached_session.access_token if cached_session

          params = LighthouseParamsFactory.new(@user.icn, :health).build
          response = config.access_token_connection.post('', params)
          token_hash = response.body
          session = LighthouseSession.new(token_hash.symbolize_keys)
          LighthouseSession.set_cached(@user, session, session.expires_in)
          session.access_token
        end
      end
    end
  end
end
