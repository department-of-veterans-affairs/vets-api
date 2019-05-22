# frozen_string_literal: true

module ClaimsApi
  class ApplicationController < ::OpenidApplicationController
    skip_before_action :set_tags_and_extra_context, raise: false
    before_action :log_request
    before_action :verify_power_of_attorney, if: :poa_request?
    before_action :verify_mvi

    private

    def log_request
      if @current_user.present?
        hashed_ssn = Digest::SHA2.hexdigest @current_user.ssn
        Rails.logger.info('Claims App Request', 'lookup_identifier' => hashed_ssn)
      else
        hashed_ssn = Digest::SHA2.hexdigest ssn
        Rails.logger.info('Claims App Request',
                          'consumer' => consumer,
                          'va_user' => requesting_va_user,
                          'lookup_identifier' => hashed_ssn)
      end
    end

    def log_response(additional_fields = {})
      logged_info = {
        'consumer' => consumer,
        'va_user' => requesting_va_user
      }.merge(additional_fields)
      Rails.logger.info('Claims App Response', logged_info)
    end

    def consumer
      header(key = 'X-Consumer-Username') ? header(key) : raise_missing_header(key)
    end

    def ssn
      header(key = 'X-VA-SSN') ? header(key) : raise_missing_header(key)
    end

    def requesting_va_user
      header('X-VA-User') || header('X-Consumer-Username')
    end

    def header(key)
      request.headers[key]
    end

    def raise_missing_header(key)
      raise Common::Exceptions::ParameterMissing, key
    end

    def target_veteran(with_gender: false)
      if poa_request?
        vet = ClaimsApi::Veteran.from_headers(request.headers, with_gender: with_gender)
        vet.loa = @current_user.loa if @current_user
        vet
      else
        ClaimsApi::Veteran.from_identity(identity: @current_user)
      end
    end

    def verify_power_of_attorney
      verifier = EVSS::PowerOfAttorneyVerifier.new(target_veteran)
      verifier.verify(@current_user)
    end

    def verify_mvi
      unless target_veteran.mvi_record?
        render json: { errors: [{ detail: 'Not found' }] },
               status: :not_found
      end
    end

    def poa_request?
      # if any of the required headers are present we should attempt to use headers
      headers_to_check = ['HTTP_X_VA_SSN', 'HTTP_X_VA_Consumer-Username', 'HTTP_X_VA_Birth_Date']
      (request.headers.to_h.keys & headers_to_check).length.positive?
    end
  end
end
