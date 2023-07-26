# frozen_string_literal: true

require 'common/client/base'
require 'dgi/contact_info/configuration'
require 'dgi/service'
require 'dgi/contact_info/response'
require 'authentication_token_service'

module MebApi
  module DGI
    module ContactInfo
      class Service < MebApi::DGI::Service
        configuration MebApi::DGI::ContactInfo::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.contact_info'

        def check_for_duplicates(email_params, phone_params)
          params = ActionController::Parameters.new({ emails: email_params, phones: phone_params })
          with_monitoring do
            options = { timeout: 60 }
            response = perform(:post, duplicates_end_point, camelize_keys_for_java_service(params).to_json, headers,
                               options)

            # @NOTE: Mocked values is DGI is not wanted/needed
            # response = {
            #   body: {
            #     email: [
            #       { address: 'test@test.com', isDupe: 'false' }
            #     ],
            #     phone: [
            #       { number: '8013090123', isDupe: 'false' }
            #     ]
            #   }
            # }
            MebApi::DGI::ContactInfo::Response.new(200, response)
          end
        end

        private

        def duplicates_end_point
          'utility/checkDuplicateContacts'
        end

        def headers
          {
            Authorization: "Bearer #{MebApi::AuthenticationTokenService.call}"
          }
        end

        def camelize_keys_for_java_service(params)
          local_params = params[0] || params

          local_params.permit!.to_h.deep_transform_keys do |key|
            if key.include?('_')
              split_keys = key.split('_')
              split_keys.collect { |key_part| split_keys[0] == key_part ? key_part : key_part.capitalize }.join
            else
              key
            end
          end
        end
      end
    end
  end
end
