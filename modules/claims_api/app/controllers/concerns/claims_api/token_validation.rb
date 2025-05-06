# frozen_string_literal: true

require 'mpi/responses/find_profile_response'
require 'mpi/service'

module ClaimsApi
  module TokenValidation
    extend ActiveSupport::Concern
    TOKEN_REGEX = /Bearer /

    included do
      # Determine if the current authenticated user is allowed access
      # raise if current authenticated user is neither the target veteran, nor target veteran representative
      def verify_access!
        @validated_token = validate_token!
        @validated_token_data = @validated_token&.validated_token_data
        @is_valid_ccg_flow ||= @validated_token&.client_credentials_token?
        raise ::Common::Exceptions::Unauthorized if @validated_token_data.nil?
        return if @is_valid_ccg_flow

        @current_user = user_from_validated_token(@validated_token_data)
      end

      def validate_token!
        root_url = request.base_url == 'https://api.va.gov' ? 'https://api.va.gov' : 'https://sandbox-api.va.gov'
        token_validation_url = if Settings.claims_api.token_validation.url.nil?
                                 "#{root_url}/internal/auth/v3/validation"
                               else
                                 Settings.claims_api.token_validation.url
                               end
        token_string = token_string_from_request
        audience = "#{root_url}/services/claims"
        ValidatedToken.new(token_validation_url, token_string, audience)
      rescue ::Common::Exceptions::TokenValidationError => e
        raise ::Common::Exceptions::Unauthorized.new(detail: e.detail)
      rescue => e
        raise ::Common::Exceptions::Unauthorized if e.to_s.include?('401')
      end
    end

    def get_user_info!
      root_url = request.base_url == 'https://api.va.gov' ? 'https://api.va.gov' : 'https://sandbox-api.va.gov'
      user_info_url = if Settings.claims_api.user_info.nil? || Settings.claims_api.user_info.url.nil?
                        "#{root_url}/internal/auth/v3/userinfo"
                      else
                        Settings.claims_api.user_info.url
                      end
      token_string = token_string_from_request
      audience = "#{root_url}/services/claims"
      UserInfo.new(user_info_url, token_string, audience)
    rescue => e
      raise ::Common::Exceptions::Unauthorized if e.to_s.include?('401')
    end

    def token
      @validated_token ||= verify_access!
    end

    def token_string_from_request
      auth_request = request.authorization.to_s
      return unless auth_request[TOKEN_REGEX]

      auth_request.sub(TOKEN_REGEX, '').gsub(/^"|"$/, '')
    end

    def mpi_service
      @mpi_service ||= MPI::Service.new
    end

    def user_from_validated_token(validated_token)
      user_info = get_user_info!
      attributes = validated_token['attributes']
      uid = attributes['uid']
      act = attributes['act']
      icn = act['icn']
      create_claim_user(act, icn, uid, user_info)
    end

    def permit_scopes(scopes, actions: [])
      return false unless @validated_token_data

      attributes = @validated_token_data['attributes']
      if (actions.empty? ||
        Array.wrap(actions).map(&:to_s).include?(action_name)) && !Array.wrap(scopes).intersect?(attributes['scp'])
        render_unauthorized
      end
    end

    private

    def create_claim_user(act, icn, uid, user_info)
      claims_user = ClaimsUser.new(uid)
      user_info_content = user_info&.user_info_content
      claims_user.email = user_info_content['email']
      if icn.nil?
        claims_user.first_name_last_name(act['first_name'], act['last_name']) unless act['last_name'].nil?
        claims_user.middle_name = act['middle_name'] unless act['middle_name'].nil?
      else
        claims_user.set_icn(icn)
        mpi_profile = mpi_service.find_profile_by_identifier(identifier: icn, identifier_type: MPI::Constants::ICN)
        claims_user.set_ssn(mpi_profile&.profile&.ssn)
        last_name = mpi_profile&.profile&.family_name
        first_name = mpi_profile&.profile&.given_names&.first
        claims_user.first_name_last_name(first_name, last_name)
        middle_name = mpi_profile&.profile&.given_names&.second
        claims_user.middle_name = middle_name unless middle_name.nil?
        suffix = mpi_profile&.profile&.suffix
        claims_user.suffix = suffix unless suffix.nil?
      end
      claims_user
    end
  end
end
