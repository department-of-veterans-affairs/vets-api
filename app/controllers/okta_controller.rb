# frozen_string_literal: true

class OktaController < ApplicationController
  skip_before_action :authenticate, only: [:metadata]

  def metadata
    meta = OneLogin::RubySaml::Metadata.new
    render xml: meta.generate(saml_settings), content_type: 'application/xml'
  end

  # TODO: parse through claims and construct user object
  # TODO: reference MviUsersController
  def fetch_mvi_profile(json_request)
    # TODO: pull out info from Okta request for querying MVI
    user_attributes = JSON.parse(json_request)

    user_identity = build_identity_from_attributes(user_attributes)
    service = MVI::Service.new
    mvi_response = service.find_profile(user_identity)
    raise mvi_response.error if mvi_response.error # TODO: add error logging
    mvi_response
    #  ^ this response will be in format lib/mvi/models/mvi_profile.rb
  end

  # TODO: receive and parse JSON request, and send commands to modify
  def okta_callback
    # TODO: parse request params from Okta into usable format
    # fetch mvi profile using
    fetch_mvi_profile(params)
    # ^ iterate through profile attributes and construct appropriate Okta response

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
