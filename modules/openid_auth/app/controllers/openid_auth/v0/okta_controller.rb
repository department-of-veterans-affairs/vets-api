# frozen_string_literal: true

require_dependency 'openid_auth/application_controller'

module OpenidAuth
  module V0
    class OktaController < ApplicationController
      skip_before_action :authenticate

      def parse_user_attributes(json_request)
        okta_attributes = json_request.dig(:data, :assertion, :claims)
        user_attributes = Hash.new
        okta_attributes.each do |k, v|
          user_attributes[k.to_sym] = v[:attributeValues][0][:value]
        end
        user_attributes
      end

      def fetch_mvi_profile(user_attributes)
        user_identity = OpenidUserIdentity.new(
          birth_date: user_attributes[:dob],
          dslogon_edipi: user_attributes[:dslogon_edipi],
          email: user_attributes[:user_email],
          first_name: user_attributes[:first_name],
          gender: user_attributes[:gender]&.chars&.first&.upcase,
          last_name: user_attributes[:last_name],
          loa:
          {
            current: user_attributes[:level_of_assurance].to_i,
            highest: user_attributes[:level_of_assurance].to_i
          },
          mhv_icn: user_attributes[:mhv_icn],
          ssn: user_attributes[:ssn],
          uuid: user_attributes[:idp_uuid]
        )

        mvi_response = MVI::Service.new.find_profile(user_identity)

        raise mvi_response.error if mvi_response.error # TODO: add error logging
        mvi_response[:profile]
      end

      def okta_callback
        user_attributes = parse_user_attributes(params)
        mvi_profile = fetch_mvi_profile(user_attributes)

        render json: {
          "commands": [
            {
              "type": "com.okta.assertion.patch",
              "value": [
                {
                  "op": "replace",
                  "path": "/claims/dslogon_edipi/attributeValues/0/value",
                  "value": mvi_profile[:edipi]
                },
                {
                  "op": "add",
                  "path": "/claims/icn_with_aaid",
                  "value": {
                    "attributes": {
                      "NameFormat": "urn:oasis:names:tc:SAML:2.0:attrname-format:basic"
                    },
                    "attributeValues": [
                      {
                        "attributes": {
                          "xsi:type": "xs:string"
                        },
                        "value": mvi_profile[:icn_with_aaid]
                      }
                    ]
                  }
                }
              ]
            }
          ]
        }
      end
    end
  end
end
