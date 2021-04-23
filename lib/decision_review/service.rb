# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'common/exceptions/forbidden'
require 'common/exceptions/schema_validation_errors'
require 'decision_review/configuration'
require 'decision_review/service_exception'
require 'decision_review/schemas'

module DecisionReview
  ##
  # Proxy Service for the Lighthouse Decision Reviews API.
  #
  class Service < Common::Client::Base
    include SentryLogging
    include Common::Client::Concerns::Monitoring

    configuration DecisionReview::Configuration

    STATSD_KEY_PREFIX = 'api.decision_review'
    HLR_CREATE_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'HLR-CREATE-RESPONSE-200'
    HLR_SHOW_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'HLR-SHOW-RESPONSE-200'
    HLR_GET_CONTESTABLE_ISSUES_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'HLR-GET-CONTESTABLE-ISSUES-RESPONSE-200'
    REQUIRED_CREATE_NOTICE_OF_DISAGREEMENT_HEADERS = %w[X-VA-Veteran-First-Name X-VA-Veteran-Last-Name
                                                        X-VA-Veteran-SSN X-VA-Veteran-Birth-Date].freeze
    REQUIRED_CREATE_HIGHER_LEVEL_REVIEW_HEADERS = %w[X-VA-First-Name X-VA-Last-Name X-VA-SSN X-VA-Birth-Date].freeze

    ##
    # Create a Higher-Level Review
    #
    # @param request_body [JSON] JSON serialized version of a Higher-Level Review Form (20-0996)
    # @param user [User] Veteran who the form is in regard to
    # @return [Faraday::Response]
    #
    def create_higher_level_review(request_body:, user:)
      with_monitoring_and_error_handling do
        headers = create_higher_level_review_headers(user)
        response = perform :post, 'higher_level_reviews', request_body, headers
        raise_schema_error_unless_200_status response.status
        validate_against_schema json: response.body, schema: HLR_CREATE_RESPONSE_SCHEMA, append_to_error_class: ' (HLR)'
        response
      end
    end

    ##
    # Create a Notice of Disagreement
    #
    # @param request_body [JSON] JSON serialized version of a Notice of Disagreement Form (10182)
    # @param user [User] Veteran who the form is in regard to
    # @return [Faraday::Response]
    #
    def create_notice_of_disagreement(request_body:, user:)
      with_monitoring_and_error_handling do
        headers = create_notice_of_disagreement_headers(user)
        response = perform :post, 'notice_of_disagreements', request_body, headers
        raise_schema_error_unless_200_status response.status
        validate_against_schema(
          json: response.body, schema: Schemas::NOD_CREATE_RESPONSE_200, append_to_error_class: ' (NOD)'
        )
        response
      end
    end

    ##
    # Retrieve a Higher-Level Review
    #
    # @param uuid [uuid] A Higher-Level Review's UUID (included in a create_higher_level_review response)
    # @return [Faraday::Response]
    #
    def get_higher_level_review(uuid)
      with_monitoring_and_error_handling do
        response = perform :get, "higher_level_reviews/#{uuid}", nil
        raise_schema_error_unless_200_status response.status
        validate_against_schema json: response.body, schema: HLR_SHOW_RESPONSE_SCHEMA, append_to_error_class: ' (HLR)'
        response
      end
    end

    ##
    # Retrieve a Notice of Disagreement
    #
    # @param uuid [uuid] A Notice of Disagreement's UUID (included in a create_notice_of_disagreement response)
    # @return [Faraday::Response]
    #
    def get_notice_of_disagreement(uuid)
      with_monitoring_and_error_handling do
        response = perform :get, "notice_of_disagreements/#{uuid}", nil
        raise_schema_error_unless_200_status response.status
        validate_against_schema(
          json: response.body, schema: Schemas::NOD_SHOW_RESPONSE_200, append_to_error_class: ' (NOD)'
        )
        response
      end
    end

    ##
    # Get Contestable Issues for a Higher-Level Review
    #
    # @param user [User] Veteran who the form is in regard to
    # @param benefit_type [String] Type of benefit the decision review is for
    # @return [Faraday::Response]
    #
    def get_higher_level_review_contestable_issues(user:, benefit_type:)
      with_monitoring_and_error_handling do
        path = "higher_level_reviews/contestable_issues/#{benefit_type}"
        headers = get_contestable_issues_headers(user)
        response = perform :get, path, nil, headers
        raise_schema_error_unless_200_status response.status
        validate_against_schema(
          json: response.body,
          schema: HLR_GET_CONTESTABLE_ISSUES_RESPONSE_SCHEMA,
          append_to_error_class: ' (HLR)'
        )
        response
      end
    end

    ##
    # Get Contestable Issues for a Notice of Disagreement
    #
    # @param user [User] Veteran who the form is in regard to
    # @return [Faraday::Response]
    #
    def get_notice_of_disagreement_contestable_issues(user:)
      with_monitoring_and_error_handling do
        path = 'notice_of_disagreements/contestable_issues'
        headers = get_contestable_issues_headers(user)
        response = perform :get, path, nil, headers
        raise_schema_error_unless_200_status response.status
        validate_against_schema(
          json: response.body,
          schema: Schemas::NOD_CONTESTABLE_ISSUES_RESPONSE_200,
          append_to_error_class: ' (NOD)'
        )
        response
      end
    end

    ##
    # Get the url to upload supporting evidenc for a Notice of Disagreement
    #
    # @param uuid The uuid of the submited Notice of Disagreement
    # @return [Faraday::Response]
    #

    def get_notice_of_disagreement_upload_url(nod_id:)
      with_monitoring_and_error_handling do
        perform :post, 'notice_of_disagreements/evidence_submissions', nod_id: nod_id
      end
    end

    def put_notice_of_disagreement_upload(path:, file_path:, metadata:)
      params = { metadata: metadata }
      params[:content] = Faraday::UploadIO.new(file_path, Mime[:pdf].to_s)
      with_monitoring_and_error_handling do
        perform :put, path, params, nil
      end
    end

    private

    def create_higher_level_review_headers(user)
      headers = {
        'X-VA-SSN' => user.ssn.to_s.strip.presence,
        'X-VA-First-Name' => user.first_name.to_s.strip.first(12),
        'X-VA-Middle-Initial' => middle_initial(user),
        'X-VA-Last-Name' => user.last_name.to_s.strip.first(18).presence,
        'X-VA-Birth-Date' => user.birth_date.to_s.strip.presence,
        'X-VA-File-Number' => nil,
        'X-VA-Service-Number' => nil,
        'X-VA-Insurance-Policy-Number' => nil
      }.compact

      missing_required_fields = REQUIRED_CREATE_HIGHER_LEVEL_REVIEW_HEADERS - headers.keys
      if missing_required_fields.present?
        raise Common::Exceptions::Forbidden.new(
          source: "#{self.class}##{__method__}",
          detail: { missing_required_fields: missing_required_fields }
        )
      end

      headers
    end

    def create_notice_of_disagreement_headers(user)
      headers = {
        'X-VA-Veteran-First-Name' => user.first_name.to_s.strip, # can be an empty string for those with 1 legal name
        'X-VA-Veteran-Middle-Initial' => middle_initial(user),
        'X-VA-Veteran-Last-Name' => user.last_name.to_s.strip.presence,
        'X-VA-Veteran-SSN' => user.ssn.to_s.strip.presence,
        'X-VA-Veteran-File-Number' => nil,
        'X-VA-Veteran-Birth-Date' => user.birth_date.to_s.strip.presence
      }.compact

      missing_required_fields = REQUIRED_CREATE_NOTICE_OF_DISAGREEMENT_HEADERS - headers.keys
      if missing_required_fields.present?
        raise Common::Exceptions::Forbidden.new(
          source: "#{self.class}##{__method__}",
          detail: { missing_required_fields: missing_required_fields }
        )
      end

      headers
    end

    def middle_initial(user)
      user.middle_name.to_s.strip.presence&.first&.upcase
    end

    def get_contestable_issues_headers(user)
      raise Common::Exceptions::Forbidden.new source: "#{self.class}##{__method__}" unless user.ssn

      {
        'X-VA-SSN' => user.ssn.to_s,
        'X-VA-Receipt-Date' => Time.zone.now.strftime('%Y-%m-%d')
      }
    end

    def with_monitoring_and_error_handling
      with_monitoring(2) do
        yield
      end
    rescue => e
      handle_error(e)
    end

    def save_error_details(error)
      Raven.tags_context external_service: self.class.to_s.underscore
      Raven.extra_context url: config.base_path, message: error.message
    end

    def handle_error(error)
      save_error_details error
      source_hash = { source: "#{error.class} raised in #{self.class}" }

      raise case error
            when Faraday::ParsingError
              DecisionReview::ServiceException.new key: 'DR_502', response_values: source_hash
            when Common::Client::Errors::ClientError
              Raven.extra_context body: error.body, status: error.status
              if error.status == 403
                Common::Exceptions::Forbidden.new source_hash
              else
                DecisionReview::ServiceException.new(
                  key: "DR_#{error.status}",
                  response_values: source_hash,
                  original_status: error.status,
                  original_body: error.body
                )
              end
            else
              error
            end
    end

    def validate_against_schema(json:, schema:, append_to_error_class: '')
      errors = JSONSchemer.schema(schema).validate(json).to_a
      return if errors.empty?

      raise Common::Exceptions::SchemaValidationErrors, remove_pii_from_json_schemer_errors(errors)
    rescue => e
      PersonalInformationLog.create!(
        error_class: "#{self.class.name}#validate_against_schema exception #{e.class}#{append_to_error_class}",
        data: {
          json: json, schema: schema, errors: errors,
          error: Class.new.include(FailedRequestLoggable).exception_hash(e)
        }
      )
      raise
    end

    def raise_schema_error_unless_200_status(status)
      return if status == 200

      raise Common::Exceptions::SchemaValidationErrors, ["expecting 200 status received #{status}"]
    end

    def remove_pii_from_json_schemer_errors(errors)
      errors.map { |error| error.slice 'data_pointer', 'schema', 'root_schema' }
    end
  end
end
