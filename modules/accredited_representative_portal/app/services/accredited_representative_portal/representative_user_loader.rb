# frozen_string_literal: true

module AccreditedRepresentativePortal
  class RepresentativeUserLoader
    attr_reader :access_token, :request_ip

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
      validate_representative_status
      current_user
    end

    def validate_account_and_session
      raise SignIn::Errors::SessionNotFoundError.new message: 'Invalid Session Handle' unless session
    end

    def validate_representative_status
      mpi_profile = mpi_service.find_profile_by_identifier(identifier: session.user_account.icn,
                                                           identifier_type: MPI::Constants::ICN).profile
      representative = Veteran::Service::Representative.for_user(first_name: session.user_attributes_hash['first_name'],
                                                                 last_name: session.user_attributes_hash['last_name'],
                                                                 ssn: mpi_profile.ssn,
                                                                 dob: mpi_profile.birth_date)

      if representative.blank?
        raise AccreditedRepresentativePortal::Errors::RepresentativeRecordNotFoundError.new(message: 'User is not a VA representative')
      end
    end

    def loa
      current_loa = user_is_verified? ? SignIn::Constants::Auth::LOA_THREE : SignIn::Constants::Auth::LOA_ONE
      { current: current_loa, highest: SignIn::Constants::Auth::LOA_THREE }
    end

    def sign_in
      { service_name: user_verification.credential_type,
        client_id: session.client_id,
        auth_broker: SignIn::Constants::Auth::BROKER_CODE }
    end

    def authn_context
      if user_verification.credential_type == SignIn::Constants::Auth::LOGINGOV
        SignIn::Constants::Auth::LOGIN_GOV_IAL2
      else
        SignIn::Constants::Auth::IDME_LOA3
      end
    end

    def user_is_verified?
      session.user_account.verified?
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
      user.icn = session.user_account.icn
      user.email = session.credential_email
      user.first_name = session.user_attributes_hash['first_name']
      user.last_name = session.user_attributes_hash['last_name']
      user.fingerprint = request_ip
      user.authn_context = authn_context
      user.loa = loa
      user.logingov_uuid = user_verification.logingov_uuid
      user.idme_uuid = user_verification.idme_uuid || user_verification.backing_idme_uuid
      user.last_signed_in = session.created_at
      user.sign_in = sign_in
      user.save

      @current_user = user
    end

    def mpi_service
      @service ||= MPI::Service.new
    end
  end
end
