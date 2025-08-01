# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_claims/configuration'
require 'lighthouse/benefits_claims/constants'
require 'lighthouse/benefits_claims/service_exception'
require 'lighthouse/service_exception'

module BenefitsClaims
  class Service < Common::Client::Base
    configuration BenefitsClaims::Configuration
    STATSD_KEY_PREFIX = 'api.benefits_claims'

    FILTERED_STATUSES = %w[CANCELED ERRORED PENDING].freeze

    # #90936 - according to the research done here,
    # the 960 and 290 EP Codes were flagged as a claim groups that
    # should be filtered out before they are sent to VA.gov and Mobile
    FILTERED_BASE_END_PRODUCT_CODES = %w[960 290].freeze

    SUPPRESSED_EVIDENCE_REQUESTS = ['Attorney Fees', 'Secondary Action Required', 'Stage 2 Development'].freeze

    def initialize(icn)
      @icn = icn
      if icn.blank?
        raise ArgumentError, 'no ICN passed in for LH API request.'
      else
        super()
      end
    end

    def get_claims(lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      claims = config.get("#{@icn}/claims", lighthouse_client_id, lighthouse_rsa_key_path, options).body
      claims['data'] = filter_by_status(claims['data'])
      claims['data'] = filter_by_ep_code(claims['data']) if Flipper.enabled?(:cst_filter_ep_codes)
      claims
    rescue Faraday::TimeoutError
      raise BenefitsClaims::ServiceException.new({ status: 504 }), 'Lighthouse Error'
    rescue Faraday::ClientError, Faraday::ServerError => e
      raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
    end

    def get_claim(id, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      claim = config.get("#{@icn}/claims/#{id}", lighthouse_client_id, lighthouse_rsa_key_path, options).body
      # Manual status override for certain tracked items
      # See https://github.com/department-of-veterans-affairs/va-mobile-app/issues/9671
      # This should be removed when the items are re-categorized by BGS
      override_tracked_items(claim['data']) if Flipper.enabled?(:cst_override_pmr_pending_tracked_items)
      apply_friendlier_language(claim['data']) if Flipper.enabled?(:cst_friendly_evidence_requests)
      claim
    rescue Faraday::TimeoutError
      raise BenefitsClaims::ServiceException.new({ status: 504 }), 'Lighthouse Error'
    rescue Faraday::ClientError, Faraday::ServerError => e
      raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
    end

    def get_power_of_attorney(lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      config.get("#{@icn}/power-of-attorney", lighthouse_client_id, lighthouse_rsa_key_path, options).body
    rescue Faraday::TimeoutError
      raise BenefitsClaims::ServiceException.new({ status: 504 }), 'Lighthouse Error'
    rescue Faraday::ClientError, Faraday::ServerError => e
      raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
    end

    def get_2122_submission(
      id, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {}
    )
      config.get("#{@icn}/power-of-attorney/#{id}", lighthouse_client_id, lighthouse_rsa_key_path, options).body
    rescue Faraday::TimeoutError
      raise BenefitsClaims::ServiceException.new({ status: 504 }), 'Lighthouse Error'
    rescue Faraday::ClientError, Faraday::ServerError => e
      raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
    end

    def submit2122(attributes, lighthouse_client_id = nil,
                   lighthouse_rsa_key_path = nil, options = {})
      data = { data: { attributes: } }
      config.post(
        "#{@icn}/2122", data, lighthouse_client_id, lighthouse_rsa_key_path, options
      )
    rescue Faraday::TimeoutError
      raise BenefitsClaims::ServiceException.new({ status: 504 }), 'Lighthouse Error'
    rescue Faraday::ClientError, Faraday::ServerError => e
      raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
    end

    def submit5103(id, tracked_item_id = nil, options = {})
      config.post("#{@icn}/claims/#{id}/5103", {
                    data: {
                      type: 'form/5103',
                      attributes: {
                        trackedItemIds: [
                          tracked_item_id
                        ]
                      }
                    }
                  }, nil, nil, options).body
    rescue Faraday::TimeoutError
      raise BenefitsClaims::ServiceException.new({ status: 504 }), 'Lighthouse Error'
    rescue Faraday::ClientError, Faraday::ServerError => e
      raise BenefitsClaims::ServiceException.new(e.response), 'Lighthouse Error'
    end

    def get_intent_to_file(type, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      endpoint = 'benefits_claims/intent_to_file'
      path = "#{@icn}/intent-to-file/#{type}"
      config.get(path, lighthouse_client_id, lighthouse_rsa_key_path, options).body
    rescue Faraday::ClientError, Faraday::ServerError => e
      handle_error(e, lighthouse_client_id, endpoint)
    end

    # For type "survivor", the request must include claimantSsn and be made by a valid Veteran Representative.
    # If the Representative is not a Veteran or a VA employee, this method is currently not available to them,
    # and they should use the Benefits Intake API as an alternative.
    def create_intent_to_file(type, claimant_ssn, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil,
                              options = {})
      if claimant_ssn.blank? && type == 'survivor'
        raise ArgumentError, 'BenefitsClaims::Service: No SSN provided for survivor type create request.'
      end

      endpoint = 'benefits_claims/intent_to_file'
      path = "#{@icn}/intent-to-file"
      config.post(
        path,
        {
          data: {
            type: 'intent_to_file',
            attributes: {
              type:,
              claimantSsn: claimant_ssn
            }
          }
        },
        lighthouse_client_id, lighthouse_rsa_key_path, options
      ).body
    rescue Faraday::ClientError, Faraday::ServerError => e
      handle_error(e, lighthouse_client_id, endpoint)
    end

    # submit form526 to Lighthouse API endpoint:
    # /services/claims/v2/veterans/{veteranId}/526/synchronous,
    # /services/claims/v2/veterans/{veteranId}/526/generatePdf,
    # or /services/claims/v2/veterans/{veteranId}/526 (asynchronous)
    # @param [hash || Requests::Form526] body: a hash representing the form526
    # attributes in the Lighthouse request schema
    # @param [string] lighthouse_client_id: the lighthouse_client_id requested from Lighthouse
    # @param [string] lighthouse_rsa_key_path: absolute path to the rsa key file
    # @param [hash] options: options to override aud_claim_url, params, and auth_params
    # @option options [hash] :body_only only return the body from the request
    # @option options [string] :aud_claim_url option to override the aud_claim_url for LH Veteran Verification APIs
    # @option options [hash] :auth_params a hash to send in auth params to create the access token
    # @option options [hash] :generate_pdf call the generatePdf endpoint to receive the 526 pdf
    # @option options [hash] :asynchronous call the asynchronous endpoint
    # @option options [hash] :transaction_id submission endpoint tracking
    def submit526(body, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      endpoint, path = submit_endpoint(options)

      body = prepare_submission_body(body, options[:transaction_id])
      response = config.post(
        path,
        body,
        lighthouse_client_id, lighthouse_rsa_key_path, options
      )

      submit_response(response, options[:body_only])
    rescue Faraday::ClientError, Faraday::ServerError => e
      handle_error(e, lighthouse_client_id, endpoint)
    end

    # submit form526 to Lighthouse API endpoint:
    # /services/claims/v2/veterans/{veteranId}/526/validate
    # @param [hash || Requests::Form526] body: a hash representing the form526
    # attributes in the Lighthouse request schema
    # @param [string] lighthouse_client_id: the lighthouse_client_id requested from Lighthouse
    # @param [string] lighthouse_rsa_key_path: absolute path to the rsa key file
    # @param [hash] options: options to override aud_claim_url, params, and auth_params
    # @option options [hash] :body_only only return the body from the request
    #
    # NOTE: This method is similar to submit526. The only difference is the path and endpoint values
    #
    def validate526(body, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      endpoint = '{icn}/526/validate'
      path = "#{@icn}/526/validate"
      body = prepare_submission_body(body, options[:transaction_id])

      response = config.post(
        path,
        body,
        lighthouse_client_id,
        lighthouse_rsa_key_path,
        options
      )

      submit_response(response, options[:body_only])
    rescue  Faraday::ClientError,
            Faraday::ServerError => e
      handle_error(e, lighthouse_client_id, endpoint)
    end

    private

    def build_request_body(body, transaction_id = "vagov-#{SecureRandom}")
      body = body.as_json
      if body.dig('data', 'attributes').nil?
        body = {
          data: {
            type: 'form/526',
            attributes: body
          },
          meta: {
            transaction_id:
          }
        }
      end
      body.as_json.deep_transform_keys { |k| k.camelize(:lower) }
    end

    def prepare_submission_body(body, transaction_id)
      # if we're coming straight from the transformation service without
      # making this a jsonapi request body first ({data: {type:, attributes}, meta: {transactionId:}}),
      # this will put it in the correct format for transmission
      body = build_request_body(body, transaction_id)

      # Inflection settings force 'current_va_employee' to render as 'currentVAEmployee' in the above camelize() call
      # Since Lighthouse needs 'currentVaEmployee', the following workaround renames it.
      fix_current_va_employee(body)

      # LH PDF generator service crashes with having an empty array for confinements
      # removes confinements from the request body if confinements attribute empty or nil
      remove_empty_array(body, 'serviceInformation', 'confinements')

      # Lighthouse expects at least 1 element in the multipleExposures array if it is not null
      # this removes the multipleExposures array if it is empty
      remove_empty_array(body, 'toxicExposure', 'multipleExposures')

      body
    end

    def fix_current_va_employee(body)
      if body.dig('data', 'attributes', 'veteranIdentification')&.select do |field|
           field['currentVAEmployee']
         end&.key?('currentVAEmployee')
        body['data']['attributes']['veteranIdentification']['currentVaEmployee'] =
          body['data']['attributes']['veteranIdentification']['currentVAEmployee']
        body['data']['attributes']['veteranIdentification'].delete('currentVAEmployee')
      end
    end

    def remove_empty_array(body, parent_key, child_key)
      if body.dig('data', 'attributes', parent_key)&.select do |field|
        field[child_key]
      end&.key?(child_key) && body['data']['attributes'][parent_key][child_key].blank?
        body['data']['attributes'][parent_key].delete(child_key)
      end
    end

    def submit_response(response, body_only)
      if body_only
        # return only the response body
        response.body
      else
        # return the whole response
        response
      end
    end

    # chooses the path and endpoint for submission
    # "synchronous" is the default
    def submit_endpoint(options)
      # nothing past the "526" in the path means asynchronous endpoint
      endpoint = '{icn}/526'
      path = "#{@icn}/526"

      if options[:generate_pdf].present?
        path = "#{@icn}/526/generatePDF/minimum-validations"
        endpoint = '{icn}/526/generatePDF/minimum-validations'
      end

      # "synchronous" should be the default
      if options[:asynchronous].blank? && options[:generate_pdf].blank?
        path = "#{@icn}/526/synchronous"
        endpoint = '{icn}/526/synchronous'
      end

      [endpoint, path]
    end

    def filter_by_status(items)
      items.reject { |item| FILTERED_STATUSES.include?(item.dig('attributes', 'status')) }
    end

    def filter_by_ep_code(items)
      items.reject { |item| FILTERED_BASE_END_PRODUCT_CODES.include?(item.dig('attributes', 'baseEndProductCode')) }
    end

    def override_tracked_items(claim)
      tracked_items = claim['attributes']['trackedItems']
      return unless tracked_items

      tracked_items.select { |i| i['displayName'] == 'PMR Pending' }.each do |i|
        i['status'] = 'NEEDED_FROM_OTHERS'
      end

      tracked_items.select { |i| i['displayName'] == 'Proof of service (DD214, etc.)' }.each do |i|
        i['status'] = 'NEEDED_FROM_OTHERS'
      end
      tracked_items
    end

    def apply_friendlier_language(claim)
      tracked_items = claim['attributes']['trackedItems']
      return unless tracked_items

      tracked_items.each do |i|
        display_name = i['displayName']
        i['canUploadFile'] =
          BenefitsClaims::Constants::UPLOADER_MAPPING[display_name].nil? ||
          BenefitsClaims::Constants::UPLOADER_MAPPING[display_name]
        i['friendlyName'] = BenefitsClaims::Constants::FRIENDLY_DISPLAY_MAPPING[display_name]
        i['activityDescription'] = BenefitsClaims::Constants::ACTIVITY_DESCRIPTION_MAPPING[display_name]
        i['shortDescription'] = BenefitsClaims::Constants::SHORT_DESCRIPTION_MAPPING[display_name]
        i['supportAliases'] = BenefitsClaims::Constants::SUPPORT_ALIASES_MAPPING[display_name] || []
      end
      tracked_items
    end

    def handle_error(error, lighthouse_client_id, endpoint)
      Lighthouse::ServiceException.send_error(
        error,
        self.class.to_s.underscore,
        lighthouse_client_id,
        "#{config.base_api_path}/#{endpoint}"
      )
    end
  end
end
