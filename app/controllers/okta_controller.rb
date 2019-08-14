# frozen_string_literal: true

class OktaController < ApplicationController
  skip_before_action :authenticate, only: [:metadata]

  def metadata
    meta = OneLogin::RubySaml::Metadata.new
    render xml: meta.generate(saml_settings), content_type: 'application/xml'
  end

  def modify_okta_response(saml_response)
    user_session_form = UserSessionForm.new(saml_response)
    if user_session_form.valid?
      user = user_session_form.user
      # TODO: compare Okta response and augment with attributes from user object
    else
      # log_message_to_sentry(
      #   user_session_form.errors_message, user_session_form.errors_hash[:level], user_session_form.errors_context
      # ) TBD error logging
    end
  end

  # receives SAML response, and sends commands to modify
  def okta_callback
    saml_response = SAML::Responses::Login.new(params[:SAMLResponse], settings: saml_settings)

    if saml_response.valid?
      modify_okta_response(saml_response)

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
    else
      log_error(saml_response)
      # stats(:failure, saml_response, saml_response.error_instrumentation_code) TBD stats logging
    end
  rescue StandardError => e
    log_exception_to_sentry(e, {}, {}, :error)
    # stats(:failed_unknown) TBD stats logging
  ensure
    # stats(:total) TBD stats logging
  end
end
