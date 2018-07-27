# frozen_string_literal: true

module Gibft
  class Service < Salesforce::Service
    configuration Gibft::Configuration

    CONSUMER_KEY = Settings.salesforce.consumer_key
    SIGNING_KEY_PATH = Settings.salesforce.signing_key_path
    SALESFORCE_USERNAME = SALESFORCE_USERNAMES[Settings.salesforce.env]


    def add_user_data!(converted_form, user)
      profile_data = converted_form['profile_data']
      va_profile = user.va_profile

      add_loa3_overrides!(converted_form, user) if user.loa3?

      if va_profile.present?
        profile_data['sec_ID'] = va_profile.sec_id
        profile_data['active_ICN'] = user.icn
        profile_data['historical_ICN'] = va_profile.historical_icns
      end

      if user.edipi.present?
        title38_status =
          begin
            user.veteran_status.title38_status
          rescue EMISRedis::VeteranStatus::RecordNotFound
            nil
          end

        converted_form['title38_status'] = title38_status
      end

      Common::HashHelpers.deep_compact(converted_form)
    end

    def get_client
      Restforce.new(
        oauth_token: get_oauth_token,
        instance_url: SALESFORCE_INSTANCE_URL,
        api_version: '41.0'
      )
    end

    def submit(form, user)
      converted_form = convert_form(form)
      add_user_data!(converted_form, user) if user.present?

      client = get_client
      response_body = client.post('/services/apexrest/VICRequest', converted_form).body
      Raven.extra_context(submit_response_body: response_body)

      case_id = response_body['case_id']

      {
        case_id: case_id,
        case_number: response_body['case_number']
      }
    end
  end
end
