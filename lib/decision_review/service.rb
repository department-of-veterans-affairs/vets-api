# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'

require 'decision_review/configuration'
require 'decision_review/responses/response'
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
        raw_response = perform(:post, 'higher_level_reviews', request_body, post_higher_level_reviews_headers(user))
        DecisionReview::Responses::Response.new(raw_response.status, raw_response.body, 'HLR-CREATE-RESPONSE-200')
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
        raw_response = perform(:get, "higher_level_reviews/#{uuid}", nil)
        DecisionReview::Responses::Response.new(raw_response.status, raw_response.body, 'HLR-SHOW-RESPONSE-200')
      end
    end

    def get_higher_level_review_contestable_issues(user:, benefit_type:)
      with_monitoring_and_error_handling do
        raw_response = perform(:get, "higher_level_reviews/contestable_issues/#{benefit_type}", nil, get_contestable_issues_headers(user))
        DecisionReview::Responses::Response.new(raw_response.status, raw_response.body, 'HLR-GET-CONTESTABLE-ISSUES-RESPONSE-200')
      end
    end

    private

    def post_higher_level_reviews_headers(user)
      raise Common::Exceptions::Forbidden unless user.ssn && user.first_name && user.last_name && user.birth_date

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
      raise Common::Exceptions::Forbidden unless user.ssn

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
      Raven.tags_context(
        external_service: self.class.to_s.underscore
      )

      Raven.extra_context(
        url: config.base_path,
        message: error.message,
        body: error.body
      )
    end

    def raise_backend_exception(key, source, error = nil)
      raise DecisionReview::ServiceException.new(
        key,
        { source: source.to_s },
        error&.status,
        error&.body
      )
    end

    def handle_error(error)
      case error
      when Faraday::ParsingError
        Raven.extra_context(
          message: error.message,
          url: config.base_path
        )
        raise_backend_exception('DR_502', self.class)
      when Common::Client::Errors::ClientError
        save_error_details(error)
        raise Common::Exceptions::Forbidden if error.status == 403
        raise raise_backend_exception('DR_401', self.class, error) if error.status == 401

        code = error.body['errors'].first.dig('code')
        raise_backend_exception("DR_#{code}", self.class, error)
      else
        raise error
      end
    end
  end
end
