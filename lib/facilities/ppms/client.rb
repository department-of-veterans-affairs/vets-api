# frozen_string_literal: true

require 'common/client/base'
require 'facilities/ppms/response'

module Facilities
  module PPMS
    # Core class responsible for api interface operations
    # Web forum and documentation (latest version of the ICD) located at:
    # https://vaww.oed.portal.va.gov/pm/iehr/vista_evolution/RA/CCP_PPMS/PPMS_DWS/SitePages/Home.aspx
    # Dev swagger site for testing endpoints
    # https://dev.dws.ppms.va.gov/swagger
    class Client < Common::Client::Base
      configuration Facilities::PPMS::Configuration

      # https://dev.dws.ppms.va.gov/swagger/ui/index#!/GlobalFunctions/GlobalFunctions_ProviderLocator
      def provider_locator(params)
        qparams = provider_locator_params(params)
        response = perform(:get, 'v1.0/ProviderLocator', qparams)

        return [] if response.body.nil?

        trim_response_attributes!(response)
        deduplicate_response_arrays!(response)

        paginated_responses(
          Facilities::PPMS::Response.from_provider_locator(response, params),
          params
        )
      end

      def pos_locator(params)
        walkin_params      = pos_locator_params(params, 17)
        urgent_care_params = pos_locator_params(params, 20)

        walkin_response      = perform(:get, 'v1.0/PlaceOfServiceLocator', walkin_params)
        urgent_care_response = perform(:get, 'v1.0/PlaceOfServiceLocator', urgent_care_params)

        responses = [
          [walkin_params, walkin_response],
          [urgent_care_params, urgent_care_response]
        ].each_with_object([]) do |(request_params, response), new_array|
          next if response.body.blank?

          trim_response_attributes!(response)
          deduplicate_response_arrays!(response)

          providers = Facilities::PPMS::Response.from_provider_locator(response, request_params)
          providers.each do |provider|
            provider.posCodes = request_params[:posCodes]
            provider.ProviderType = 'GroupPracticeOrAgency'
            provider.set_hexdigest!
          end
          new_array.concat(providers)
        end.sort
        paginated_responses(responses, params)
      end

      # https://dev.dws.ppms.va.gov/swagger/ui/index#!/Providers/Providers_Get_0
      def provider_info(identifier)
        qparams = { :$expand => 'ProviderSpecialties' }
        response = perform(:get, "v1.0/Providers(#{identifier})", qparams)
        return nil if response.body.nil? || response.body[0].nil?

        trim_response_attributes!(response)
        deduplicate_response_arrays!(response)

        Facilities::PPMS::Response.new(response.body[0], response.status).new_provider
      end

      def provider_caresites(site_name)
        response = perform(:get, 'v1.0/CareSites()', name: "'#{site_name}'")

        trim_response_attributes!(response)
        deduplicate_response_arrays!(response)

        Facilities::PPMS::Response.new(response.body, response.status).get_body
      end

      def provider_services(identifier)
        response = perform(:get, "v1.0/Providers(#{identifier})/ProviderServices", {})

        trim_response_attributes!(response)
        deduplicate_response_arrays!(response)

        Facilities::PPMS::Response.new(response.body, response.status).get_body
      end

      # https://dev.dws.ppms.va.gov/swagger/ui/index#!/Specialties/Specialties_Get_0
      def specialties
        response = perform(:get, 'v1.0/Specialties', {})
        Facilities::PPMS::Response.new(response.body, response.status).get_body
      end

      private

      def paginated_responses(response, params)
        page = Integer(params[:page] || 1)
        per_page = Integer(params[:per_page] || BaseFacility.per_page)
        offset = (page - 1) * per_page

        response[offset, per_page] || []
      end

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

      def radius(bbox)
        # more estimation fun about 69 miles between latitude lines, <= 69 miles between long lines
        bbox_num = bbox.map { |x| Float(x) }

        lats = bbox_num.values_at(1, 3)
        longs = bbox_num.values_at(2, 0)
        xlen = (lats.max - lats.min) * 69 / 2
        ylen = (longs.max - longs.min) * 69 / 2
        (Math.sqrt(xlen * xlen + ylen * ylen) * 1.1).round # go a little bit beyond the corner;
      end

      def pos_locator_params(params, pos_code)
        page = Integer(params[:page] || 1)
        per_page = Integer(params[:per_page] || BaseFacility.per_page)
        {
          address: "'#{params[:address]}'",
          radius: radius(params[:bbox]),
          driveTime: 10_000,
          posCodes: pos_code,
          network: 0,
          maxResults: per_page * page + 1
        }
      end

      def provider_locator_params(params)
        if Flipper.enabled?(:facility_locator_ppms_location_query)
          provider_locator_location_params(params)
        else
          provider_locator_address_params(params)
        end
      end

      def provider_locator_address_params(params)
        page = Integer(params[:page] || 1)
        per_page = Integer(params[:per_page] || BaseFacility.per_page)
        specialty = "'#{params[:services] ? params[:services][0] : 'null'}'"
        {
          address: "'#{params[:address]}'",
          radius: radius(params[:bbox]),
          driveTime: 10_000,
          specialtycode1: specialty,
          specialtycode2: 'null',
          specialtycode3: 'null',
          specialtycode4: 'null',
          network: 0,
          gender: 0,
          primarycare: 0,
          acceptingnewpatients: 0,
          maxResults: per_page * page + 1
        }
      end

      def provider_locator_location_params(params)
        page = Integer(params[:page] || 1)
        per_page = Integer(params[:per_page] || BaseFacility.per_page)
        specialty = "'#{params[:services] ? params[:services][0] : 'null'}'"
        cnr = center_and_radius(params[:bbox])

        {
          address: [cnr[:latitude], cnr[:longitude]].join(','),
          radius: cnr[:radius],
          driveTime: 10_000,
          specialtycode1: specialty,
          specialtycode2: 'null',
          specialtycode3: 'null',
          specialtycode4: 'null',
          network: 0,
          gender: 0,
          primarycare: 0,
          acceptingnewpatients: 0,
          maxResults: per_page * page + 1
        }
      end
    end
  end
end
