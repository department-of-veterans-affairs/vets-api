# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  class DiscoveryController < ApplicationController
    skip_before_action :authenticate

    API_VERSION_MAP = {
      deprecated: {
        min_build_number: {
          ios: 0,
          android: 0
        },
        max_build_number: {
          ios: 19,
          android: 19
        },
        api_version: 'deprecated',
        webviews: {
        },
        endpoints: {
        },
        display_message: 'Please update the app.',
        app_access: false
      },
      one_zero: {
        min_build_number: {
          ios: 20,
          android: 20
        },
        max_build_number: {
          ios: 999,
          android: 999
        },
        api_version: '1.0',
        webviews: {
          corona_FAQ: 'https://www.va.gov/coronavirus-veteran-frequently-asked-questions',
          facility_locator: 'https://www.va.gov/find-locations/'
        },
        endpoints: {
          appeal_details: {
            url: '/appeal/:id',
            method: 'GET'
          },
          appointments: {
            url: '/appointments',
            method: 'GET'
          },
          claims_overview: {
            url: '/claims-and-appeals-overview',
            method: 'GET'
          },
          claim_details: {
            url: '/claim/:id',
            method: 'GET'
          },
          upload_claim_documents: {
            url: '/claim/:id/documents',
            method: 'POST'
          },
          available_letters: {
            url: '/letters',
            method: 'GET'
          },
          letters_beneficiary: {
            url: '/letters/beneficiary',
            method: 'GET'
          },
          letters_download: {
            url: '/letters/:type/download',
            method: 'POST'
          },
          service_history: {
            url: '/military-service-history',
            method: 'GET'
          },
          get_payment_info: {
            url: '/payment-information/benefits',
            method: 'GET'
          },
          update_payment_info: {
            url: '/payment-information/benefits',
            method: 'PUT'
          },
          user: {
            url: '/user',
            method: 'GET'
          },
          logout: {
            url: '/user/logout',
            method: 'GET'
          },
          create_user_addresses: {
            url: '/user/addresses',
            method: 'POST'
          },
          update_user_addresses: {
            url: '/user/addresses',
            method: 'PUT'
          },
          user_address_validation: {
            url: '/user/addresses/validate',
            method: 'POST'
          },
          create_user_email: {
            url: '/user/emails',
            method: 'POST'
          },
          update_user_email: {
            url: '/user/emails',
            method: 'PUT'
          },
          create_user_phone: {
            url: '/user/phones',
            method: 'POST'
          },
          update_user_phone: {
            url: '/user/phones',
            method: 'PUT'
          }
        },
        display_message: '',
        app_access: true
      }
    }.freeze

    OAUTH_ENV_MAP = {
      dev: 'https://sqa.fed.eauth.va.gov/oauthe/sps/oauth/oauth20/',
      staging: 'https://int.fed.eauth.va.gov/oauthe/sps/oauth/oauth20/',
      prod: 'https://fed.eauth.va.gov/oauthe/sps/oauth/oauth20/'
    }.freeze

    API_ROOT_ENV_MAP = {
      dev: 'https://staging-api.va.gov/mobile',
      staging: 'https://staging-api.va.gov/mobile',
      prod: 'https://api.va.gov/mobile'
    }.freeze

    def welcome
      render json: { data: { attributes: { message: 'Welcome to the mobile API' } } }
    end

    def index
      response = OpenStruct.new
      versioned_api_info = get_api_version(params[:buildNumber].to_i, params[:os])
      response.id = versioned_api_info[:api_version]
      response.webviews = versioned_api_info[:webviews]
      response.endpoints = versioned_api_info[:endpoints]
      response.display_message = versioned_api_info[:display_message]
      response.app_access = versioned_api_info[:app_access]
      response.oauth_base_url = get_env_specific_url(params[:environment], OAUTH_ENV_MAP)
      response.api_root_url = get_env_specific_url(params[:environment], API_ROOT_ENV_MAP)
      render json: Mobile::V0::DiscoverySerializer.new(response)
    end

    def get_api_version(build_number, os)
      API_VERSION_MAP.each do |_version, values|
        if get_os_build_number(values[:max_build_number], os) >= build_number &&
           get_os_build_number(values[:min_build_number], os) <= build_number
          return values
        end
      end
    end

    def get_os_build_number(values, os)
      os == 'android' ? values[:android] : values[:ios]
    end

    def get_env_specific_url(environment, url_map)
      url_map.each do |key, value|
        return value if key.to_s.match(environment)
      end
    end
  end
end
