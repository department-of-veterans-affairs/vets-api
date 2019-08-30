# frozen_string_literal: true
require 'openid_auth'

class OktaController < ApplicationController
  include OpenidAuth::V0
  skip_before_action :authenticate

  def metadata
    meta = OneLogin::RubySaml::Metadata.new
    render xml: meta.generate(saml_settings), content_type: 'application/xml'
  end

  def fetch_mvi_profile(json_request)
    # TODO: pull out info from Okta request for querying MVI. Put into helper func
    okta_attributes = json_request.dig(:data, :assertion, :claims)
    user_attributes = Hash.new
    okta_attributes.each do |k, v|
      user_attributes[k] = v[:attributeValues][0][:value]
    end
    user_attributes["authn_context"] = json_request[:data][:assertion][:authentication][:authnContext][:authnContextClassRef]
    
    binding.pry
    user_identity = OpenidAuth::V0::MviUsersController.new.build_identity_from_attributes(user_attributes)
    service = MVI::Service.new
    mvi_response = service.find_profile(user_identity)
    raise mvi_response.error if mvi_response.error # TODO: add error logging
    mvi_response
    #  ^ this response will be in format lib/mvi/models/mvi_profile.rb
  end

  def okta_callback
    puts request.raw_post.to_json
    fetch_mvi_profile(params)

    render json: {
      "commands": [
        {
          "type": "com.okta.assertion.patch",
          "value": [
            {
              "op": "replace",
              "path": "/claims/first_name/attributeValues/0/value",
              "value": "New first name"
            },
            {
              "op": "add",
              "path": "/claims/newValue",
              "value": {
                "attributes": {
                  "NameFormat": "urn:oasis:names:tc:SAML:2.0:attrname-format:basic"
                },
                "attributeValues": [
                  {
                    "attributes": {
                      "xsi:type": "xs:string"
                    },
                    "value": "Here's a new value"
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
