# frozen_string_literal: true

module AccreditedRepresentativePortal
  # NOTE: This class currently only supports 21a Unaccredited Representatives.
  # For 2122, Accredited Representative User Progress, see the below WIP ARP Auth epic:
  # https://app.zenhub.com/workspaces/accredited-representative-facing-team-65453a97a9cc36069a2ad1d6/issues/gh/department-of-veterans-affairs/va.gov-team/75746
  class RepresentativeUserLoader
    attr_reader :access_token, :request_ip

    class RepresentativeNotFoundError < StandardError; end

    def initialize(access_token:, request_ip:)
      @access_token = access_token
      @request_ip = request_ip
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
      if FeatureToggle.enabled?(:accredited_representative_portal_self_service_auth)

        email = session.credential_email
        raise Common::Exceptions::Unauthorized, detail: 'Email not provided' unless email.present?

        icn = session.user_account.icn
        registration_number = AccreditedRepresentativePortal::OGCClient.new.find_registration_number_for_icn(icn)

        if registration_number.blank?
          representatives = Veteran::Service::Representative.where(email: email)

          if representatives.empty?
            raise Common::Exceptions::Unauthorized, 
                  detail: 'Email not associated with any accredited representative'
          elsif representatives.size > 1
            raise Common::Exceptions::Unauthorized,
                  detail: 'Email associated with multiple accredited representatives'
          end
          representative = representatives.first
          registration_number = representative.representative_id
        end

        # register the icn with the OGC API
        AccreditedRepresentativePortal::OGCClient.new.post_icn_and_registration_combination(icn, registration_number)
        
        session.rep_registration_number = registration_number
      end
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

    def current_user
      return @current_user if @current_user.present?

      user = RepresentativeUser.new
      user.uuid = access_token.user_uuid
      user.user_account_uuid = session.user_account.id
      user.icn = session.user_account.icn
      user.email = session.credential_email
      user.first_name = session.user_attributes_hash['first_name']
      user.last_name = session.user_attributes_hash['last_name']
      user.fingerprint = request_ip
      user.authn_context = authn_context
      user.loa = loa
      user.logingov_uuid = user_verification.logingov_uuid
      user.idme_uuid = user_verification.idme_uuid
      user.last_signed_in = session.created_at
      user.sign_in = sign_in
      user.save

      @current_user = user
    end
  end
end
