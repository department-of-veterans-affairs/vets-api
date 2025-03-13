# frozen_string_literal: true

require 'appeals_api/health_checker'

module AppealsApi
  class MetadataController < ::ApplicationController
    service_tag 'lighthouse-appeals'
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    skip_before_action(:authenticate)
    before_action :set_default_headers

    WARNING_EMOJI = ':warning:'

    def decision_reviews
      render json: {
        meta: {
          versions: decision_reviews_versions
        }
      }
    end

    def appeals_status
      render json: {
        meta: {
          versions: [
            {
              version: '0.0.1',
              internal_only: true,
              status: VERSION_STATUS[:current],
              path: '/services/appeals/docs/v0/api',
              healthcheck: '/services/appeals/v0/healthcheck'
            }
          ]
        }
      }
    end

    def healthcheck
      render json: {
        description: 'Appeals API health check',
        status: 'pass',
        time: Time.zone.now.to_formatted_s(:iso8601)
      }
    end

    # Treat s3 as an internal resource as opposed to an upstream service per VA
    def healthcheck_s3
      http_status_code = 200
      s3_heathy = s3_is_healthy?
      unless s3_heathy
        begin
          http_status_code = 503
          slack_details = {
            class: self.class.name,
            warning: "#{WARNING_EMOJI} Appeals API healthcheck failed: unable to connect to AWS S3 bucket."
          }
          AppealsApi::Slack::Messager.new(slack_details).notify!
        rescue => e
          Rails.logger.error("Appeals API S3 failed Healthcheck slack notification failed: #{e.message}", e)
        end
      end
      render json: {
        description: 'Appeals API health check',
        status: s3_heathy ? 'pass' : 'fail',
        time: Time.zone.now.to_formatted_s(:iso8601)
      }, status: http_status_code
    end

    def s3_is_healthy?
      # Internally, appeals defers to Benefits Intake for s3 ops, so we check the BI buckets
      # using the BI Settings
      s3 = Aws::S3::Resource.new(region: Settings.vba_documents.s3.region,
                                 access_key_id: Settings.vba_documents.s3.aws_access_key_id,
                                 secret_access_key: Settings.vba_documents.s3.aws_secret_access_key)
      s3.client.head_bucket({ bucket: Settings.vba_documents.s3.bucket })
      true
    rescue
      false
    end

    def mail_status_upstream_healthcheck
      mail_status_code = proc do
        health_checker.mail_services_are_healthy? ? 200 : 503
      rescue => e
        Rails.logger.error('AppealsApi Mail Status Healthcheck error', status: e.status, message: e.body)
        503
      end

      render_upstream_services_response(
        health_checker.mail_services_are_healthy?,
        AppealsApi::HealthChecker::MAIL_SERVICES,
        mail_status_code.call
      )
    end

    def appeals_status_upstream_healthcheck
      appeals_status_code = proc do
        health_checker.appeals_services_are_healthy? ? 200 : 503
      rescue => e
        Rails.logger.error('AppealsApi Appeals Status Healthcheck error', status: e.status, message: e.body)
        503
      end

      render_upstream_services_response(
        health_checker.appeals_services_are_healthy?,
        AppealsApi::HealthChecker::APPEALS_SERVICES,
        appeals_status_code.call
      )
    end

    def decision_reviews_upstream_healthcheck
      decision_reviews_status_code = proc do
        health_checker.decision_reviews_services_are_healthy? ? 200 : 503
      rescue => e
        Rails.logger.error('AppealsApi Decision Reviews Healthcheck error', status: e.status, message: e.body)
        503
      end

      render_upstream_services_response(
        health_checker.decision_reviews_services_are_healthy?,
        AppealsApi::HealthChecker::DECISION_REVIEWS_SERVICES,
        decision_reviews_status_code.call
      )
    end

    private

    def set_default_headers
      AppealsApi::ApplicationController::DEFAULT_HEADERS.each { |k, v| response.headers[k] = v }
    end

    def health_checker
      @health_checker ||= AppealsApi::HealthChecker.new
    end

    def render_upstream_services_response(services_are_healthy, services, status_code)
      time = Time.zone.now.to_formatted_s(:iso8601)

      render json: {
        description: 'Appeals API upstream health check',
        status: services_are_healthy ? 'UP' : 'DOWN',
        time:,
        details: {
          name: 'All upstream services',
          upstreamServices: services.map do |service|
            upstream_service_details(service, time)
          end
        }
      }, status: status_code
    end

    def upstream_service_details(service_name, time)
      healthy = health_checker.healthy_service?(service_name)

      service_details_response(service_name, healthy, time)
    rescue
      service_details_response(service_name, false, time)
    end

    def service_details_response(service_name, healthy, time)
      {
        description: service_name.titleize,
        status: healthy ? 'UP' : 'DOWN',
        details: {
          name: service_name.titleize,
          statusCode: healthy ? 200 : 503,
          status: healthy ? 'OK' : 'Unavailable',
          time:
        }
      }
    end

    def decision_reviews_versions
      [
        decision_reviews_v1,
        decision_reviews_v2
      ]
    end

    def decision_reviews_v1
      {
        version: '1.0.0',
        internal_only: true,
        status: VERSION_STATUS[:previous],
        path: '/services/appeals/docs/v1/decision_reviews',
        healthcheck: '/services/appeals/v1/healthcheck'
      }
    end

    def decision_reviews_v2
      {
        version: '2.0.0',
        internal_only: true,
        status: VERSION_STATUS[:current],
        path: '/services/appeals/v2/decision_reviews/docs',
        healthcheck: '/services/appeals/v2/decision_reviews/healthcheck'
      }
    end
  end
end
