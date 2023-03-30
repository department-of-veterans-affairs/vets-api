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
    REQUIRED_CREATE_HEADERS = %w[X-VA-First-Name X-VA-Last-Name X-VA-SSN X-VA-Birth-Date].freeze

    NO_ZIP_PLACEHOLDER = '00000'

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
    # Get the url to upload supporting evidence for a Notice of Disagreement
    #
    # @param nod_uuid [uuid] The uuid of the submited Notice of Disagreement
    # @return [Faraday::Response]
    #

    def get_notice_of_disagreement_upload_url(nod_uuid:, ssn:)
      with_monitoring_and_error_handling do
        perform :post, 'notice_of_disagreements/evidence_submissions', { nod_uuid: },
                { 'X-VA-SSN' => ssn.to_s.strip.presence }
      end
    end

    ##
    # Get the url to upload supporting evidence for a Notice of Disagreement
    #
    # @param upload_url [String] The url for the document to be uploaded
    # @param file_path [String] The file path for the document to be uploaded
    # @param metadata [Hash] additional data
    #
    # @return [Faraday::Response]
    #

    def put_notice_of_disagreement_upload(upload_url:, file_upload:, metadata_string:)
      content_tmpfile = Tempfile.new(file_upload.filename, encoding: file_upload.read.encoding)
      content_tmpfile.write(file_upload.read)
      content_tmpfile.rewind

      json_tmpfile = Tempfile.new('metadata.json', encoding: 'utf-8')
      json_tmpfile.write(metadata_string)
      json_tmpfile.rewind

      params = { metadata: Faraday::UploadIO.new(json_tmpfile.path, Mime[:json].to_s, 'metadata.json'),
                 content: Faraday::UploadIO.new(content_tmpfile.path, Mime[:pdf].to_s, file_upload.filename) }

      # when we upgrade to Faraday >1.0
      # params = { metadata: Faraday::FilePart.new(json_tmpfile, Mime[:json].to_s, 'metadata.json'),
      #            content: Faraday::FilePart.new(content_tmpfile, Mime[:pdf].to_s, file_upload.filename) }
      with_monitoring_and_error_handling do
        perform :put, upload_url, params, { 'Content-Type' => 'multipart/form-data' }
      end
    ensure
      content_tmpfile.close
      content_tmpfile.unlink
      json_tmpfile.close
      json_tmpfile.unlink
    end

    ##
    # Returns all of the data associated with a specific Notice of Disagreement Evidence Submission.
    #
    # @param guid [uuid] the uuid returnd from get_notice_of_disagreement_upload_url
    #
    # @return [Faraday::Response]
    #

    def get_notice_of_disagreement_upload(guid:)
      with_monitoring_and_error_handling do
        perform :get, "notice_of_disagreements/evidence_submissions/#{guid}", nil
      end
    end

    def self.file_upload_metadata(user)
      {
        'veteranFirstName' => transliterate_name(user.first_name),
        'veteranLastName' => transliterate_name(user.last_name),
        'zipCode' => user.postal_code || NO_ZIP_PLACEHOLDER,
        'fileNumber' => user.ssn.to_s.strip,
        'source' => 'Vets.gov',
        'businessLine' => 'BVA'
      }.to_json
    end

    # upstream requirements
    # ^[a-zA-Z\-\/\s]{1,50}$
    # Cannot be missing or empty or longer than 50 characters.
    # Only upper/lower case letters, hyphens(-), spaces and forward-slash(/) allowed
    def self.transliterate_name(str)
      I18n.transliterate(str.to_s).gsub(%r{[^a-zA-Z\-/\s]}, '').strip.first(50)
    end

    private

    def create_higher_level_review_headers(user)
      headers = {
        'X-VA-SSN' => user.ssn.to_s.strip.presence,
        'X-VA-ICN' => user.icn.presence,
        'X-VA-First-Name' => user.first_name.to_s.strip.first(12),
        'X-VA-Middle-Initial' => middle_initial(user),
        'X-VA-Last-Name' => user.last_name.to_s.strip.first(18).presence,
        'X-VA-Birth-Date' => user.birth_date.to_s.strip.presence,
        'X-VA-File-Number' => nil,
        'X-VA-Service-Number' => nil,
        'X-VA-Insurance-Policy-Number' => nil
      }.compact

      missing_required_fields = REQUIRED_CREATE_HEADERS - headers.keys
      if missing_required_fields.present?
        raise Common::Exceptions::Forbidden.new(
          source: "#{self.class}##{__method__}",
          detail: { missing_required_fields: }
        )
      end

      headers
    end

    def create_notice_of_disagreement_headers(user)
      headers = {
        'X-VA-First-Name' => user.first_name.to_s.strip, # can be an empty string for those with 1 legal name
        'X-VA-Middle-Initial' => middle_initial(user),
        'X-VA-Last-Name' => user.last_name.to_s.strip.presence,
        'X-VA-SSN' => user.ssn.to_s.strip.presence,
        'X-VA-ICN' => user.icn.presence,
        'X-VA-File-Number' => nil,
        'X-VA-Birth-Date' => user.birth_date.to_s.strip.presence
      }.compact

      missing_required_fields = REQUIRED_CREATE_HEADERS - headers.keys
      if missing_required_fields.present?
        raise Common::Exceptions::Forbidden.new(
          source: "#{self.class}##{__method__}",
          detail: { missing_required_fields: }
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

    def with_monitoring_and_error_handling(&)
      with_monitoring(2, &)
    rescue => e
      handle_error(e)
    end

    def save_error_details(error)
      PersonalInformationLog.create!(
        error_class: "#{self.class.name}#save_error_details exception #{error.class} (HLR) (NOD)",
        data: { error: Class.new.include(FailedRequestLoggable).exception_hash(error) }
      )
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
          json:, schema:, errors:,
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
