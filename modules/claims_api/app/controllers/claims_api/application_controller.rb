# frozen_string_literal: true

require 'evss/error_middleware'
require 'bgs/power_of_attorney_verifier'

module ClaimsApi
  class ApplicationController < ::OpenidApplicationController
    include ClaimsApi::MPIVerification
    include ClaimsApi::HeaderValidation
    include ClaimsApi::JsonFormatValidation

    skip_before_action :set_tags_and_extra_context, raise: false
    before_action :validate_json_format, if: -> { request.post? }

    def show
      find_claim
    rescue => e
      log_message_to_sentry('Error in claims show',
                            :warning,
                            body: e.message)
      render json: { errors: [{ status: 404, detail: 'Claim not found' }] },
             status: :not_found
    end

    def fetch_aud
      Settings.oidc.isolated_audience.claims
    end

    protected

    def source_name
      if v0?
        request.headers['X-Consumer-Username']
      else
        user = header_request? ? @current_user : target_veteran
        "#{user.first_name} #{user.last_name}"
      end
    end

    private

    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def find_claim
      claim = ClaimsApi::AutoEstablishedClaim.find_by(id: params[:id], source: source_name)

      if claim && claim.status == 'errored'
        fetch_errored(claim)
      elsif claim && claim.evss_id.blank?
        render json: claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
      elsif claim && claim.evss_id.present?
        evss_claim = claims_service.update_from_remote(claim.evss_id)
        render json: evss_claim, serializer: ClaimsApi::ClaimDetailSerializer, uuid: claim.id
      elsif /^\d{2,20}$/.match?(params[:id])
        evss_claim = claims_service.update_from_remote(params[:id])
        # Note: source doesn't seem to be accessible within a remote evss_claim
        render json: evss_claim, serializer: ClaimsApi::ClaimDetailSerializer
      else
        render json: { errors: [{ status: 404, detail: 'Claim not found' }] },
               status: :not_found
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    def fetch_errored(claim)
      if claim.evss_response&.any?
        render json: { errors: format_evss_errors(claim.evss_response['messages']) },
               status: :unprocessable_entity
      else
        render json: { errors: [{ status: 422, detail: 'Unknown EVSS Async Error' }] },
               status: :unprocessable_entity
      end
    end

    def format_evss_errors(errors)
      errors.map do |error|
        formatted = error['key'] ? error['key'].gsub('.', '/') : error['key']
        { status: 422, detail: "#{error['severity']} #{error['detail'] || error['text']}".squish, source: formatted }
      end
    end

    def claims_service
      ClaimsApi::UnsynchronizedEVSSClaimService.new(target_veteran)
    end

    def header(key)
      request.headers[key]
    end

    def header_request?
      headers_to_check = %w[HTTP_X_VA_SSN
                            HTTP_X_VA_BIRTH_DATE
                            HTTP_X_VA_FIRST_NAME
                            HTTP_X_VA_LAST_NAME]
      (request.headers.to_h.keys & headers_to_check).length.positive?
    end

    def target_veteran(with_gender: false)
      if header_request?
        headers_to_validate = %w[X-VA-SSN X-VA-First-Name X-VA-Last-Name X-VA-Birth-Date]
        headers_to_validate << 'X-VA-LOA' if v0?
        validate_headers(headers_to_validate)
        if v0?
          check_loa_level
          check_source_user
        end
        veteran_from_headers(with_gender: with_gender)
      else
        ClaimsApi::Veteran.from_identity(identity: @current_user)
      end
    end

    def v0?
      request.env['PATH_INFO'].downcase.include?('v0')
    end

    def check_source_user
      if !header('X-VA-User') && request.headers['X-Consumer-Username']
        request.headers['X-VA-User'] = request.headers['X-Consumer-Username']
      elsif !request.headers['X-Consumer-Username']
        log_message_to_sentry('Kong no longer sending X-Consumer-Username', :error,
                              body: request.body)
        validate_headers(['X-Consumer-Username'])
      end
    end

    def check_loa_level
      unless header('X-VA-LOA').try(:to_i) == 3
        render json: [],
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: ClaimsApi::ClaimListSerializer,
               status: :unauthorized
      end
    end

    def verify_power_of_attorney
      verifier = BGS::PowerOfAttorneyVerifier.new(target_veteran)
      verifier.verify(@current_user)
    end

    def veteran_from_headers(with_gender: false)
      vet = ClaimsApi::Veteran.new(
        uuid: header('X-VA-SSN')&.gsub(/[^0-9]/, ''),
        ssn: header('X-VA-SSN')&.gsub(/[^0-9]/, ''),
        first_name: header('X-VA-First-Name'),
        last_name: header('X-VA-Last-Name'),
        va_profile: ClaimsApi::Veteran.build_profile(header('X-VA-Birth-Date')),
        last_signed_in: Time.now.utc
      )
      vet.loa = if @current_user
                  @current_user.loa
                else
                  { current: header('X-VA-LOA').try(:to_i), highest: header('X-VA-LOA').try(:to_i) }
                end
      vet.mpi_record?
      vet.gender = header('X-VA-Gender') || vet.mpi.profile&.gender if with_gender
      vet.edipi = header('X-VA-EDIPI') || vet.mpi.profile&.edipi
      vet.participant_id = vet.mpi.profile&.participant_id
      vet
    end

    def authenticate_token
      super
    rescue => e
      raise e if e.message == 'Token Validation Error'

      log_message_to_sentry('Authentication Error in claims',
                            :warning,
                            body: e.message)
      render json: { errors: [{ status: 401, detail: 'User not a valid or authorized Veteran for this end point.' }] },
             status: :unauthorized
    end
  end
end
