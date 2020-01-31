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

        Facilities::PPMS::Response.from_provider_locator(response, params)
      end

      def pos_locator(params, pos_code)
        qparams = pos_locator_params(params, pos_code)
        response = perform(:get, 'v1.0/PlaceOfServiceLocator', qparams)
        return [] if response.body.nil?

        Facilities::PPMS::Response.from_provider_locator(response, params)
      end

      # https://dev.dws.ppms.va.gov/swagger/ui/index#!/Providers/Providers_Get_0
      def provider_info(identifier)
        qparams = { :$expand => 'ProviderSpecialties' }
        response = perform(:get, "v1.0/Providers(#{identifier})", qparams)
        return nil if response.body.nil? || response.body[0].nil?

        Facilities::PPMS::Response.new(response.body[0], response.status).new_provider
      end

      def provider_caresites(site_name)
        response = perform(:get, 'v1.0/CareSites()', name: "'#{site_name}'")
        Facilities::PPMS::Response.new(response.body, response.status).get_body
      end

      def provider_services(identifier)
        response = perform(:get, "v1.0/Providers(#{identifier})/ProviderServices", {})
        Facilities::PPMS::Response.new(response.body, response.status).get_body
      end

      # https://dev.dws.ppms.va.gov/swagger/ui/index#!/Specialties/Specialties_Get_0
      def specialties
        response = perform(:get, 'v1.0/Specialties', {})
        Facilities::PPMS::Response.new(response.body, response.status).get_body
      end

      private

      def radius(bbox)
        # more estimation fun about 69 miles between latitude lines, <= 69 miles between long lines
        bbox_num = bbox.map { |x| Float(x) }
        lats = bbox_num.values_at(1, 3)
        longs = bbox_num.values_at(2, 0)
        xlen = (lats.max - lats.min) * 69 / 2
        ylen = (longs.max - longs.min) * 69 / 2
        Math.sqrt(xlen * xlen + ylen * ylen) * 1.1 # go a little bit beyond the corner;
      end

      def pos_locator_params(params, pos_code)
        page = Integer(params[:page] || 1)
        {
          address: "'#{params[:address]}'",
          radius: radius(params[:bbox]),
          driveTime: 10_000,
          posCodes: pos_code,
          network: 0,
          maxResults: 20 * page + 1
        }
      end

      def provider_locator_params(params)
        page = Integer(params[:page] || 1)
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
          maxResults: 20 * page + 1
        }
      end
    end
  end
end
