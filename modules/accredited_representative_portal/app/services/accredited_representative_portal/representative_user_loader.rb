# frozen_string_literal: true

module AccreditedRepresentativePortal
  class RepresentativeUserLoader
    attr_reader :access_token, :request_ip

    class RepresentativeNotFoundError < StandardError; end

    def initialize(access_token:, request_ip:)
      @access_token = access_token
      @request_ip = request_ip
      # NOTE: a change will be necessary to support alternate emails
      # The below currently only supports the primary session email
      # See discussion: https://github.com/department-of-veterans-affairs/vets-api/pull/16493#discussion_r1579783276
      @verified_representative = VerifiedRepresentative.find_by(email: session&.credential_email) # NOTE: primary email
    end

    def perform
      find_valid_user || reload_user
    end

    private

    def find_valid_user
      RepresentativeUser.find(access_token.user_uuid)
    end

    def reload_user
      validate_account_and_session
      current_user
    end

    def validate_account_and_session
      raise SignIn::Errors::SessionNotFoundError.new message: 'Invalid Session Handle' unless session
    end

    def loa
      { current: SignIn::Constants::Auth::LOA_THREE, highest: SignIn::Constants::Auth::LOA_THREE }
    end

    def sign_in
      { service_name: user_verification.credential_type,
        client_id: session.client_id,
        auth_broker: SignIn::Constants::Auth::BROKER_CODE }
    end

    def authn_context
      case user_verification.credential_type
      when SignIn::Constants::Auth::LOGINGOV
        SignIn::Constants::Auth::LOGIN_GOV_IAL2
      when SignIn::Constants::Auth::IDME
        SignIn::Constants::Auth::IDME_LOA3
      end
    end

    def session
      @session ||= SignIn::OAuthSession.find_by(handle: access_token.session_handle)
    end

    def user_verification
      @user_verification ||= session.user_verification
    end

    # NOTE: given there will be RepresentativeUsers who are not VerifiedRepresentatives,
    # it's okay for this to return nil
    def get_ogc_registration_number
      @verified_representative&.ogc_registration_number
    end

    # NOTE: given there will be RepresentativeUsers who are not VerifiedRepresentatives,
    # it's okay for this to return nil
    def get_poa_codes
      @verified_representative&.poa_codes
    end

    def current_user
      return @current_user if @current_user.present?

      user = RepresentativeUser.new
      user.uuid = access_token.user_uuid
      user.icn = session.user_account.icn
      user.email = session.credential_email
      user.first_name = session.user_attributes_hash['first_name']
      user.last_name = session.user_attributes_hash['last_name']
      user.fingerprint = request_ip
      user.authn_context = authn_context
      user.loa = loa
      user.logingov_uuid = user_verification.logingov_uuid
      user.ogc_registration_number = get_ogc_registration_number
      user.poa_codes = get_poa_codes
      user.idme_uuid = user_verification.idme_uuid
      user.last_signed_in = session.created_at
      user.sign_in = sign_in
      user.save

      @current_user = user
    end
  end
end
