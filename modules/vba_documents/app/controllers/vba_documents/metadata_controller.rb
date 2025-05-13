# frozen_string_literal: true

require 'vba_documents/health_checker'

module VBADocuments
  class MetadataController < ::ApplicationController
    service_tag 'lighthouse-benefits-intake'
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    skip_before_action(:authenticate)

    def index
      render json: {
        meta: {
          versions: benefits_versions
        }
      }
    end

    def benefits_intake
      render json: {
        meta: {
          versions: benefits_versions
        }
      }
    end

    def benefits_versions
      if v2_enabled?
        [
          benefits_intake_v1.merge({ status: VERSION_STATUS[:previous] }),
          benefits_intake_v2
        ]
      else
        [
          benefits_intake_v1
        ]
      end
    end

    def benefits_intake_v1
      {
        version: '1.0.0',
        internal_only: false,
        status: VERSION_STATUS[:current],
        path: '/services/vba_documents/docs/v1/api',
        healthcheck: '/services/vba_documents/v1/healthcheck'
      }
    end

    def benefits_intake_v2
      {
        version: '2.0.0',
        internal_only: true,
        status: VERSION_STATUS[:current],
        path: '/services/vba_documents/docs/v2/api',
        healthcheck: '/services/vba_documents/v1/healthcheck'
      }
    end

    def v2_enabled?
      Settings.vba_documents.documentation.path_enabled_flag
    end

    def healthcheck
      http_status_code = 200
      s3_heathy = s3_is_healthy?
      unless s3_heathy
        http_status_code = 503
        Rails.logger.info("Benefits Intake S3 healthcheck failed")
      end
      render json: {
        description: 'VBA Documents API health check',
        status: s3_heathy ? 'pass' : 'fail',
        time: Time.zone.now.to_formatted_s(:iso8601)
      }, status: http_status_code
    end

    # treat s3 as a Benefits Intake internal resource as opposed to an upstream service per VA
    def s3_is_healthy?
      s3 = Aws::S3::Resource.new(region: Settings.vba_documents.s3.region,
                                 access_key_id: Settings.vba_documents.s3.aws_access_key_id,
                                 secret_access_key: Settings.vba_documents.s3.aws_secret_access_key)
      s3.client.head_bucket({ bucket: Settings.vba_documents.s3.bucket })
      true
    rescue
      false
    end

    def upstream_healthcheck
      health_checker = VBADocuments::HealthChecker.new
      time = Time.zone.now.to_formatted_s(:iso8601)

      render json: {
        description: 'VBA Documents API upstream health check',
        status: health_checker.services_are_healthy? ? 'UP' : 'DOWN',
        time:,
        details: {
          name: 'All upstream services',
          upstreamServices: VBADocuments::HealthChecker::SERVICES.map do |service|
                              upstream_service_details(service, health_checker, time)
                            end
        }
      }, status: health_checker.services_are_healthy? ? 200 : 503
    end

    private

    def upstream_service_details(service_name, health_checker, time)
      healthy = health_checker.healthy_service?(service_name)

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
  end
end
