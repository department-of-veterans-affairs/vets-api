# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'
require_relative 'response'

module FacilitiesApi
  module V1
    module PPMS
      # Core class responsible for api interface operations
      # Web forum and documentation (latest version of the ICD) located at:
      # https://vaww.oed.portal.va.gov/pm/iehr/vista_evolution/RA/CCP_PPMS/PPMS_DWS/SitePages/Home.aspx
      # Dev swagger site for testing endpoints
      # https://dev.dws.ppms.va.gov/swagger
      class Client < Common::Client::Base
        DEGREES_OF_ACCURACY = 6
        PER_PAGE = 10
        RADIUS_MAX = 500
        RADIUS_MIN = 1
        RESULTS_MAX = 50
        RESULTS_MIN = 2

        configuration FacilitiesApi::V1::PPMS::Configuration

        def facility_service_locator(params)
          qparams = facility_service_locator_params(params)
          response = perform(:get, facility_service_locator_url, qparams)

          return [] if response.body.nil? || response.body['value'].nil?

          FacilitiesApi::V1::PPMS::Response.new(response, params).providers
        end

        # https://dev.dws.ppms.va.gov/swagger/ui/index#!/GlobalFunctions/GlobalFunctions_ProviderLocator
        def provider_locator(params)
          qparams = provider_locator_params(params)
          response = perform(:get, provider_locator_url, qparams)

          return [] if response.body.nil? || response.body['value'].nil?

          FacilitiesApi::V1::PPMS::Response.new(response, params).providers
        end

        def pos_locator(params)
          qparams = pos_locator_params(params, '17,20')

          response = perform(:get, place_of_service_locator_url, qparams)

          return [] if response.body.nil? || response.body['value'].nil?

          FacilitiesApi::V1::PPMS::Response.new(response, params).places_of_service
        end

        # https://dev.dws.ppms.va.gov/swagger/ui/index#!/Specialties/Specialties_Get_0
        def specialties
          response = perform(:get, specialties_url, {})

          FacilitiesApi::V1::PPMS::Response.new(response).specialties
        end

        private

        def facility_service_locator_url
          '/dws/v1.0/FacilityServiceLocator'
        end

        def provider_locator_url
          '/dws/v1.0/ProviderLocator'
        end

        def place_of_service_locator_url
          '/dws/v1.0/PlaceOfServiceLocator'
        end

        def specialties_url
          '/dws/v1.0/Specialties'
        end

        def fetch_lat_long_and_radius(params)
          latitude = Float(params.values_at(:lat, :latitude).compact.first).round(DEGREES_OF_ACCURACY)
          longitude = Float(params.values_at(:long, :longitude).compact.first).round(DEGREES_OF_ACCURACY)
          radius = Integer(params.fetch(:radius)).clamp(RADIUS_MIN, RADIUS_MAX)

          [latitude, longitude, radius]
        end

        def facility_service_locator_params(params)
          page = Integer(params[:page] || 1)
          per_page = Integer(params[:per_page] || PER_PAGE)

          latitude, longitude, radius = fetch_lat_long_and_radius(params)

          specialties = Array.wrap(params[:specialties])
          specialty_codes = specialties.first(5).map.with_index.with_object({}) do |(code, index), hsh|
            hsh["specialtycode#{index + 1}".to_sym] = code
          end

          {
            address: [latitude, longitude].join(','),
            radius:,
            maxResults: per_page,
            pageNumber: page,
            pageSize: per_page,
            telehealthSearch: 0,
            homeHealthSearch: 0
          }.merge(specialty_codes)
        end

        def base_params(params)
          page = Integer(params[:page] || 1)
          per_page = Integer(params[:per_page] || PER_PAGE)

          latitude, longitude, radius = fetch_lat_long_and_radius(params)

          max_results = (per_page * page + 1).clamp(RESULTS_MIN, RESULTS_MAX)

          {
            address: [latitude, longitude].join(','),
            radius:,
            maxResults: max_results,
            telehealthSearch: 0,
            homeHealthSearch: 0
          }
        end

        def pos_locator_params(params, pos_code)
          base_params(params).merge(posCodes: pos_code)
        end

        def provider_locator_params(params)
          specialties = Array.wrap(params[:specialties])
          specialty_codes = specialties.first(5).map.with_index.with_object({}) do |(code, index), hsh|
            hsh["specialtycode#{index + 1}".to_sym] = code
          end

          base_params(params).merge(specialty_codes)
        end
      end
    end
  end
end
