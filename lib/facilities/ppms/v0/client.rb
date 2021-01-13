# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'
require_relative 'response'

module Facilities
  module PPMS
    module V0
      # Core class responsible for api interface operations
      # Web forum and documentation (latest version of the ICD) located at:
      # https://vaww.oed.portal.va.gov/pm/iehr/vista_evolution/RA/CCP_PPMS/PPMS_DWS/SitePages/Home.aspx
      # Dev swagger site for testing endpoints
      # https://dev.dws.ppms.va.gov/swagger
      class Client < Common::Client::Base
        MIN_RESULTS = 1
        MAX_RESULTS = 50

        configuration Facilities::PPMS::V0::Configuration

        # https://dev.dws.ppms.va.gov/swagger/ui/index#!/GlobalFunctions/GlobalFunctions_ProviderLocator
        def provider_locator(params)
          qparams = provider_locator_params(params)
          response = perform(:get, 'v1.0/ProviderLocator', qparams)

          return [] if response.body.nil?

          trim_response_attributes!(response)
          deduplicate_response_arrays!(response)

          paginated_responses(
            Facilities::PPMS::V0::Response.from_provider_locator(response, params),
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

            providers = Facilities::PPMS::V0::Response.from_provider_locator(response, request_params)
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

          Facilities::PPMS::V0::Response.new(response.body[0], response.status).new_provider
        end

        def provider_caresites(site_name)
          response = perform(:get, 'v1.0/CareSites()', name: "'#{site_name}'")

          trim_response_attributes!(response)
          deduplicate_response_arrays!(response)

          Facilities::PPMS::V0::Response.new(response.body, response.status).get_body
        end

        def provider_services(identifier)
          response = perform(:get, "v1.0/Providers(#{identifier})/ProviderServices", {})

          trim_response_attributes!(response)
          deduplicate_response_arrays!(response)

          Facilities::PPMS::V0::Response.new(response.body, response.status).get_body
        end

        # https://dev.dws.ppms.va.gov/swagger/ui/index#!/Specialties/Specialties_Get_0
        def specialties
          response = perform(:get, 'v1.0/Specialties', {})
          Facilities::PPMS::V0::Response.new(response.body, response.status).get_body
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
            maxResults: (per_page * page + 1).clamp(MIN_RESULTS, MAX_RESULTS)
          }
        end

        def provider_locator_params(params)
          page = Integer(params[:page] || 1)

          per_page = Integer(params[:per_page] || BaseFacility.per_page)

          specialty_code = params.slice(:services, :specialties).values.first
          specialty = "'#{specialty_code ? specialty_code[0] : 'null'}'"

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
            maxResults: (per_page * page + 1).clamp(MIN_RESULTS, MAX_RESULTS)
          }
        end
      end
    end
  end
end
