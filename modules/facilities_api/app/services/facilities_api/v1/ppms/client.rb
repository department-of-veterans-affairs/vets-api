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
        MIN_RESULTS = 1
        MAX_RESULTS = 50

        configuration FacilitiesApi::V1::PPMS::Configuration

        # https://dev.dws.ppms.va.gov/swagger/ui/index#!/GlobalFunctions/GlobalFunctions_ProviderLocator
        def provider_locator(params)
          qparams = provider_locator_params(params)
          response = perform(:get, 'v1.0/ProviderLocator', qparams)

          return [] if response.body.nil?

          trim_response_attributes!(response)
          deduplicate_response_arrays!(response)

          FacilitiesApi::V1::PPMS::Response.new(response.body, params).providers
        end

        def pos_locator(params)
          qparams = pos_locator_params(params, '17,20')
          response = perform(:get, 'v1.0/PlaceOfServiceLocator', qparams)

          return [] if response.body.nil?

          trim_response_attributes!(response)
          deduplicate_response_arrays!(response)

          FacilitiesApi::V1::PPMS::Response.new(response.body, params).places_of_service
        end

        # https://dev.dws.ppms.va.gov/swagger/ui/index#!/Specialties/Specialties_Get_0
        def specialties
          response = perform(:get, 'v1.0/Specialties', {})
          response.body
        end

        private

        def trim_response_attributes!(response)
          response.body.collect! do |hsh|
            hsh.each_pair.collect do |attr, value|
              if value.is_a? String
                [attr, value.gsub(/ +/, ' ').strip]
              else
                [attr, value]
              end
            end.to_h
          end
          response
        end

        def deduplicate_response_arrays!(response)
          response.body.collect! do |hsh|
            hsh.each_pair.collect do |attr, value|
              if value.is_a? Array
                [attr, value.uniq]
              else
                [attr, value]
              end
            end.to_h
          end
          response
        end

        def base_params(params)
          page = Integer(params[:page] || 1)
          per_page = Integer(params[:per_page] || BaseFacility.per_page)

          cnr = params.slice(:latitude, :longitude, :radius)

          {
            address: [cnr[:latitude], cnr[:longitude]].join(','),
            radius: cnr[:radius],
            maxResults: (per_page * page + 1).clamp(MIN_RESULTS, MAX_RESULTS)
          }
        end

        def pos_locator_params(params, pos_code)
          base_params(params).merge(posCodes: pos_code)
        end

        def provider_locator_params(params)
          specialties = Array.wrap(params[:specialties])
          specialty_codes = specialties.first(4).map.with_index.with_object({}) do |(code, index), hsh|
            hsh["specialtycode#{index + 1}".to_sym] = code
          end

          base_params(params).merge(specialty_codes)
        end
      end
    end
  end
end
