# frozen_string_literal: true

require 'unified_health_data/imaging_service'
require 'unified_health_data/serializers/imaging_study_serializer'

module MyHealth
  module V2
    class ImagingController < ApplicationController
      include MyHealth::V2::Concerns::ErrorHandler
      include SortableRecords
      service_tag 'mhv-medical-records'

      def index
        start_date = params[:start_date]
        end_date = params[:end_date]
        imaging_study_type = params[:imaging_study_type].presence || 'ALL'

        imaging_studies = sort_records(
          service.get_imaging_studies(
            start_date:,
            end_date:,
            imaging_study_type:
          ),
          params[:sort]
        )
        serialized_studies = UnifiedHealthData::Serializers::ImagingStudySerializer.new(imaging_studies).serializable_hash[:data]

        render json: serialized_studies,
               status: :ok
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e, resource_name: 'imaging studies', api_type: 'FHIR')
      end

      def thumbnails
        start_date = params[:start_date]
        end_date = params[:end_date]

        # NOTE: params[:id] is a FHIR imaging study identifier URN (e.g. 'urn-vastudy-...')
        record_id = params[:id]

        imaging_studies = service.get_imaging_study(
          start_date:,
          end_date:,
          record_id:
        )
        serialized_studies = UnifiedHealthData::Serializers::ImagingStudySerializer.new(imaging_studies).serializable_hash[:data]

        render json: serialized_studies,
               status: :ok
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e, resource_name: 'imaging study', api_type: 'FHIR')
      end

      def dicom
        start_date = params[:start_date]
        end_date = params[:end_date]

        # NOTE: params[:id] is a FHIR imaging study identifier URN (e.g. 'urn-vastudy-...')
        record_id = params[:id]

        imaging_studies = service.get_dicom_zip(
          start_date:,
          end_date:,
          record_id:
        )
        serialized_studies = UnifiedHealthData::Serializers::ImagingStudySerializer.new(imaging_studies).serializable_hash[:data]

        render json: serialized_studies,
               status: :ok
      rescue Common::Client::Errors::ClientError,
             Common::Exceptions::BackendServiceException,
             StandardError => e
        handle_error(e, resource_name: 'DICOM zip', api_type: 'FHIR')
      end

      ##
      # Proxies a thumbnail image from S3 through vets-api so the browser can load it
      # without requiring a CSP change for the S3 bucket domain.
      #
      # The frontend passes the presigned S3 URL (obtained from the `thumbnails` action)
      # as a query parameter. This action validates the URL domain against an allowlist
      # to prevent SSRF, fetches the image, and streams it back as binary JPEG.
      #
      # GET /my_health/v2/medical_records/imaging/thumbnail_proxy?url=<encoded_presigned_url>
      #
      def thumbnail_proxy
        url = params[:url]
        raise Common::Exceptions::ParameterMissing, 'url' if url.blank?

        uri = URI.parse(url)
        validate_s3_url!(uri)

        image_data = fetch_image_from_s3(uri)

        send_data image_data,
                  type: 'image/jpeg',
                  disposition: 'inline',
                  status: :ok
      rescue URI::InvalidURIError
        render json: { error: 'Invalid URL format' }, status: :bad_request
      rescue Common::Exceptions::ParameterMissing => e
        raise e
      rescue SecurityError => e
        Rails.logger.warn("Thumbnail proxy SSRF blocked: #{e.message}")
        render json: { error: 'URL not allowed' }, status: :forbidden
      rescue => e
        handle_error(e, resource_name: 'thumbnail image', api_type: 'S3')
      end

      private

      # Allowlist of S3 host patterns for thumbnail images.
      # Matches virtual-hosted-style S3 URLs in the us-gov-west-1 region.
      ALLOWED_S3_HOST_PATTERN = /\A[\w-]+\.s3[.-]us-gov-west-1\.amazonaws\.com\z/i

      ##
      # Validates that the given URI points to an allowed S3 host.
      # Raises SecurityError if the host does not match the allowlist.
      #
      # @param uri [URI] the parsed URI to validate
      # @raise [SecurityError] if the host is not an allowed S3 domain
      #
      def validate_s3_url!(uri)
        unless uri.scheme == 'https' && ALLOWED_S3_HOST_PATTERN.match?(uri.host)
          raise SecurityError, "Disallowed host: #{uri.host}"
        end
      end

      ##
      # Fetches image data from an S3 presigned URL.
      #
      # @param uri [URI] the parsed S3 presigned URL
      # @return [String] binary image data
      # @raise [Common::Exceptions::BackendServiceException] if the S3 request fails
      #
      def fetch_image_from_s3(uri)
        http_response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
          http.get(uri.request_uri)
        end

        unless http_response.is_a?(Net::HTTPSuccess)
          Rails.logger.error("Failed to fetch thumbnail from S3: HTTP #{http_response.code}")
          raise Common::Exceptions::BackendServiceException.new(
            'MR_THUMBNAIL_FETCH_ERROR', {}, http_response.code.to_i
          )
        end

        http_response.body
      end

      def service
        @service ||= UnifiedHealthData::ImagingService.new(@current_user)
      end
    end
  end
end
