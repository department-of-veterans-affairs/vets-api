# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'
require_relative 'response'

module Facilities
  module PPMS
    module V1
      # Core class responsible for api interface operations
      # Web forum and documentation (latest version of the ICD) located at:
      # https://vaww.oed.portal.va.gov/pm/iehr/vista_evolution/RA/CCP_PPMS/PPMS_DWS/SitePages/Home.aspx
      # Dev swagger site for testing endpoints
      # https://dev.dws.ppms.va.gov/swagger
      class Client < Common::Client::Base
        configuration Facilities::PPMS::V1::Configuration

        # https://dev.dws.ppms.va.gov/swagger/ui/index#!/GlobalFunctions/GlobalFunctions_ProviderLocator
        def provider_locator(params)
          qparams = provider_locator_params(params)
          response = perform(:get, 'v1.0/ProviderLocator', qparams)

          return [] if response.body.nil?

          trim_response_attributes!(response)
          deduplicate_response_arrays!(response)

          Facilities::PPMS::V1::Response.new(response.body, params).providers
        end

        def pos_locator(params)
          qparams = pos_locator_params(params, '17,20')
          response = perform(:get, 'v1.0/PlaceOfServiceLocator', qparams)

          return [] if response.body.nil?

          trim_response_attributes!(response)
          deduplicate_response_arrays!(response)

          Facilities::PPMS::V1::Response.new(response.body, params).places_of_service
        end

        # https://dev.dws.ppms.va.gov/swagger/ui/index#!/Providers/Providers_Get_0
        def provider_info(identifier)
          qparams = { :$expand => 'ProviderSpecialties' }
          response = perform(:get, "v1.0/Providers(#{identifier})", qparams)
          return nil if response.body.nil? || response.body[0].nil?

          trim_response_attributes!(response)
          deduplicate_response_arrays!(response)

          Facilities::PPMS::V1::Response.new(response.body[0]).provider
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

        EARTH_RADIUS = 3_958.8

        def rgeo_factory
          RGeo::Geographic.spherical_factory
        end

        # Distance spanned by one degree of latitude in the given units.
        def latitude_degree_distance
          2 * Math::PI * EARTH_RADIUS / 360
        end

        # Distance spanned by one degree of longitude at the given latitude.
        # This ranges from around 69 miles at the equator to zero at the poles.
        def longitude_degree_distance(latitude)
          (latitude_degree_distance * Math.cos(latitude * (Math::PI / 180))).abs
        end

        def center_and_radius(bbox)
          bbox_num = bbox.map { |x| Float(x) }
          x_min, y_min, x_max, y_max = bbox_num.values_at(1, 0, 3, 2)

          projection = RGeo::Geographic::ProjectedWindow.new(rgeo_factory, x_min, y_min, x_max, y_max)
          lat, lon = projection.center_xy
          rad = [
            (projection.height * latitude_degree_distance).round(2),
            (projection.width * longitude_degree_distance(lat)).round(2)
          ].max

          {
            latitude: lat,
            longitude: lon,
            radius: rad.round
          }
        end

        def base_params(params)
          page = Integer(params[:page] || 1)
          per_page = Integer(params[:per_page] || BaseFacility.per_page)

          cnr = center_and_radius(params[:bbox])

          {
            address: [cnr[:latitude], cnr[:longitude]].join(','),
            radius: cnr[:radius],
            maxResults: per_page * page + 1
          }
        end

        def pos_locator_params(params, pos_code)
          base_params(params).merge(posCodes: pos_code)
        end

        def provider_locator_params(params)
          specialty_codes = params[:specialties].first(4).map.with_index.with_object({}) do |(code, index), hsh|
            hsh["specialtycode#{index + 1}".to_sym] = code
          end

          specialty_codes.merge(base_params(params))
        end
      end
    end
  end
end
