# frozen_string_literal: true

require 'common/client/base'
require 'dgi/submission/configuration'
require 'dgi/service'
require 'dgi/submission/submit_claim_response'
require 'authentication_token_service'

module MebApi
  module DGI
    module Submission
      class Service < MebApi::DGI::Service
        configuration MebApi::DGI::Submission::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.submission'

        def submit_claim(params)
          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }
            response = perform(:post, end_point, format_params(params), headers, options)

            MebApi::DGI::Submission::SubmissionResponse.new(response.status, response)
          end
        end

        private

        def end_point
          'claimType/Chapter33/claimsubmission'
        end

        def request_headers
          {
            "Content-Type": 'application/json',
            Authorization: "Bearer #{MebApi::AuthenticationTokenService.call}"
          }
        end

        # rubocop:disable Metrics/MethodLength
        def format_params(params)
          claimaint_info = params&.dig(:military_claimant)&.dig(:claimant)
          contact_info = claimaint_info&.dig(:contact_info)
          additional_considerations = params&.dig(:additional_considerations)

          # @NOTE: Will need to be updated once changes are made to the front end
          claimaint_params = {
            "claimant": {
              "claimantId": 99_900_000_200_000_000,
              "suffix": '',
              "dateOfBirth": claimaint_info[:date_of_birth],
              "firstName": claimaint_info[:first_name],
              "lastName": claimaint_info[:last_name],
              "middleName": claimaint_info[:middle_name],
              "notificationMethod": claimaint_info[:notification_method],
              "contactInfo": {
                "addressLine1": contact_info[:address_line_1],
                "addressLine2": contact_info[:address_line_2],
                "city": contact_info[:city],
                "zipcode": contact_info[:zipcode],
                "emailAddress": contact_info[:email_address],
                "addressType": contact_info[:address_type],
                "mobilePhoneNumber": contact_info[:mobile_phone_number],
                "homePhoneNumber": contact_info[:home_phone_number],
                "countryCode": contact_info[:country_code],
                "stateCode": contact_info[:state_code]
              },
              "preferredContact": params[:preferred_contact] || 'EMAIL'
            },
            "relinquishedBenefit": {
              "effRelinquishDate": params[:relinquished_benefit][:eff_relinquish_date] || '1980-01-01',
              "relinquishedBenefit": params[:relinquished_benefit][:relinquished_benefit]
            },
            "additionalConsiderations": {
              "activeDutyKicker": additional_considerations[:active_duty_kicker],
              "reserveKicker": additional_considerations[:reserve_kicker],
              "academyRotcScholarship": additional_considerations[:academy_rotc_scholarship],
              "seniorRotcScholarship": additional_considerations[:senior_rotc_scholarship],
              "activeDutyDodRepayLoan": additional_considerations[:active_duty_dod_repay_loan],
              "terminalLeave": additional_considerations[:terminal_leave]
            },
            "comments": {
              "disagreeWithServicePeriod": true
            }
          }

          claimaint_params.to_json
        end
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end
