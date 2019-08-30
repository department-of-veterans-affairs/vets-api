# frozen_string_literal: true
require 'openid_auth'
require 'json'

class OktaController < ApplicationController
  include OpenidAuth::V0
  skip_before_action :authenticate

  def metadata
    meta = OneLogin::RubySaml::Metadata.new
    render xml: meta.generate(saml_settings), content_type: 'application/xml'
  end

  def parse_user_attributes(json_request)
    okta_attributes = json_request.dig(:data, :assertion, :claims)
    user_attributes = Hash.new
    okta_attributes.each do |k, v|
      user_attributes[k.to_sym] = v[:attributeValues][0][:value]
    end
    user_attributes
  end

  def fetch_mvi_profile(user_attributes)    
    user_identity = OpenidAuth::V0::MviUsersController.new.build_identity_from_attributes(user_attributes)
    mvi_response = MVI::Service.new.find_profile(user_identity)

    raise mvi_response.error if mvi_response.error # TODO: add error logging
    mvi_response[:profile]
  end

  def okta_callback
    puts JSON.pretty_generate(JSON.parse(request.raw_post))
  
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
