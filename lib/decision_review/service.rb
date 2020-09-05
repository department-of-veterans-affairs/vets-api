# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'

require 'decision_review/configuration'
require 'decision_review/service_exception'

module DecisionReview
  ##
  # Proxy Service for Decision Reviews API.
  #
  # @example Create a service and create/retrieve higher reviews
  #   response = DecisionReview::Service.new.post_higher_level_reviews(request_json)
  #
  class Service < Common::Client::Base
    include SentryLogging
    include Common::Client::Concerns::Monitoring

    configuration DecisionReview::Configuration

    STATSD_KEY_PREFIX = 'api.decision_review'

    ##
    # Create a Higher Level Review for a veteran.
    #
    # @param request_body [JSON] JSON serialized version of a Higher Level Review Form
    # @return [DecisionReview::Responses::Response] Response object that includes the body,
    #                                               status, and schema validations.
    #
    def post_higher_level_reviews(body:, user:)
      with_monitoring_and_error_handling do
        headers = post_higher_level_reviews_headers(user)
        response = perform :post, 'higher_level_reviews', body, headers
        raise_schema_error_unless_200_status response.status
        validate_against_schema response.body, 'HLR-CREATE-RESPONSE-200'
      end
    end

    ##
    # Retrieve a Higher Level Review results.
    #
    # @param uuid [uuid] The intake uuid provided from the response of creating a new Higher Level Review
    # @return [DecisionReview::Responses::Response] Response object that includes the body,
    #                                               status, and schema avalidations.
    #
    def get_higher_level_reviews(uuid)
      with_monitoring_and_error_handling do
        response = perform :get, "higher_level_reviews/#{uuid}", nil
        raise_schema_error_unless_200_status response.status
        validate_against_schema response.body, 'HLR-SHOW-RESPONSE-200'
      end
    end

    def get_higher_level_review_contestable_issues(user:, benefit_type:)
      with_monitoring_and_error_handling do
        path = "higher_level_reviews/contestable_issues/#{benefit_type}"
        headers = get_contestable_issues_headers(user)
        response = perform :get, path, nil, headers
        raise_schema_error_unless_200_status response.status
        validate_against_schema response.body, 'HLR-GET-CONTESTABLE-ISSUES-RESPONSE-200'
      end
    end

    private

    def post_higher_level_reviews_headers(user)
      unless user.ssn && user.first_name && user.last_name && user.birth_date
        raise Common::Exceptions::Forbidden.new source: "#{self.class}##{__method__}"
      end

      {
        'X-VA-SSN' => user.ssn,
        'X-VA-First-Name' => user.first_name,
        'X-VA-Middle-Initial' => user.middle_name.presence&.first,
        'X-VA-Last-Name' => user.last_name,
        'X-VA-Birth-Date' => user.birth_date,
        'X-VA-File-Number' => nil,
        'X-VA-Service-Number' => nil,
        'X-VA-Insurance-Policy-Number' => nil
      }.compact
    end

    def get_contestable_issues_headers(user)
      raise Common::Exceptions::Forbidden.new source: "#{self.class}##{__method__}" unless user.ssn

      {
        'X-VA-SSN' => user.ssn,
        'X-VA-Receipt-Date' => Time.zone.now.strftime('%F')
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

    def validate_against_schema(json:, schema_name:)
      schema = VetsJsonSchema::SCHEMAS[schema_name]
      errors = remove_pii_from_json_schemer_errors JSONSchemer.schema(schema).validate(json).to_a
      return if errors.empty?

      raise Common::Exceptions::SchemaValidationErrors, errors
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
