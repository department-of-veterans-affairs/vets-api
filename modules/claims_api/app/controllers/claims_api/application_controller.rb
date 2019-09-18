# frozen_string_literal: true

require_dependency 'claims_api/concerns/mvi_verification'
require_dependency 'claims_api/concerns/header_validation'

module ClaimsApi
  class ApplicationController < ::OpenidApplicationController
    include ClaimsApi::MviVerification
    include ClaimsApi::HeaderValidation

    skip_before_action :set_tags_and_extra_context, raise: false

    private

    def header(key)
      request.headers[key]
    end

    def header_request?
      headers_to_check = ['HTTP_X_VA_SSN', 'HTTP_X_VA_Consumer-Username', 'HTTP_X_VA_BIRTH_DATE']
      (request.headers.to_h.keys & headers_to_check).length.positive?
    end

    def target_veteran(with_gender: false)
      if header_request?

        headers_to_validate = ['X-VA-SSN', 'X-VA-First-Name', 'X-VA-Last-Name', 'X-VA-Birth-Date']
        headers_to_validate << 'X-VA-Gender' if with_gender
        headers_to_validate << 'X-VA-LOA' if v0?
        validate_headers(headers_to_validate)
        check_loa_level if v0?
        veteran_from_headers(with_gender: with_gender)
      else
        ClaimsApi::Veteran.from_identity(identity: @current_user)
      end
    end

    def v0?
      request.env['PATH_INFO'].downcase.include?('v0')
    end

    def check_loa_level
      unless header('X-VA-LOA') == '3'
        render json: [],
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: ClaimsApi::ClaimListSerializer,
               status: :unauthorized
      end
    end

    def verify_power_of_attorney
      verifier = EVSS::PowerOfAttorneyVerifier.new(target_veteran)
      verifier.verify(@current_user)
    end

    def veteran_from_headers(with_gender: false)
      vet = ClaimsApi::Veteran.new(
        uuid: header('X-VA-SSN'),
        ssn: header('X-VA-SSN'),
        first_name: header('X-VA-First-Name'),
        last_name: header('X-VA-Last-Name'),
        va_profile: ClaimsApi::Veteran.build_profile(header('X-VA-Birth-Date')),
        last_signed_in: Time.now.utc
      )
      vet.loa = @current_user.loa if @current_user
      vet.gender = header('X-VA-Gender') if with_gender
      vet.mvi_record?
      vet.edipi = header('X-VA-EDIPI') || vet.mvi.profile&.edipi
      vet
    end

    def verify_loa
      header_loa
    end
  end
end
