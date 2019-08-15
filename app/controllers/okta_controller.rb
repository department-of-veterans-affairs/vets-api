# frozen_string_literal: true

class OktaController < ApplicationController
  skip_before_action :authenticate, only: [:metadata]

  def metadata
    meta = OneLogin::RubySaml::Metadata.new
    render xml: meta.generate(saml_settings), content_type: 'application/xml'
  end

  # TODO: parse through claims and construct user object
  # TODO: reference MviUsersController
  def construct_okta_response(json_response)
    user_attributes = JSON.parse(json_response)

    user_identity = build_identity_from_attributes(user_attributes)
    service = MVI::Service.new
    mvi_response = service.find_profile(user_identity)
    raise mvi_response.error if mvi_response.error # TODO: add error logging
    mvi_response
  end

  # TODO: receive and parse JSON request, and send commands to modify
  def okta_callback
    construct_okta_response(params)

    # return JSON object
    return {
      "commands": [
        {
          "type": "com.okta.assertion.patch",
          "value": [
            {
              "op": "replace", # or add
              "path": "path/to/key",
              "value": {
                "attributeName": "attributeValue"
              }
            }
          ]
        }
      ]
    }.to_json
  end
end
