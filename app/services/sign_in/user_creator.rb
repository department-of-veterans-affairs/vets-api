# frozen_string_literal: true

module SignIn
  class UserCreator
    attr_reader :user_attributes, :state_payload

    def initialize(user_attributes:, state_payload:)
      @user_attributes = user_attributes
      @state_payload = state_payload
    end

    def perform
      check_and_add_mpi_user
      validate_mpi_record
      create_authenticated_user
      create_code_container
      user_code_map
    end

    private

    def validate_mpi_record
      raise SignIn::Errors::MPILockedAccountError, 'Theft Flag Detected' if user_for_mpi_query.id_theft_flag
      raise SignIn::Errors::MPILockedAccountError, 'Death Flag Detected' if user_for_mpi_query.deceased_date
    end

    def check_and_add_mpi_user
      return unless user_for_mpi_query.loa3? && user_for_mpi_query.icn.nil?

      mpi_response = user_for_mpi_query.mpi_add_person_implicit_search

      raise SignIn::Errors::MPIUserCreationFailedError, 'User MPI record cannot be created' unless mpi_response.ok?
    end

    def create_authenticated_user
      raise SignIn::Errors::UserAttributesMalformedError, 'User Attributes are Malformed' unless user_verification

      user = User.new
      user.instance_variable_set(:@identity, user_identity_from_mpi_query)
      user.uuid = user_verification.user_account.id
      user_identity_from_mpi_query.uuid = user_verification.user_account.id
      user.last_signed_in = Time.zone.now
      user.save && user_identity_from_mpi_query.save
    end

    def create_code_container
      SignIn::CodeContainer.new(code: login_code,
                                client_id: state_payload.client_id,
                                code_challenge: state_payload.code_challenge,
                                user_verification_id: user_verification.id,
                                credential_email: credential_email).save!
    end

    def user_identity_from_attributes
      @user_identity_from_attributes ||= UserIdentity.new(user_attributes)
    end

    def user_identity_from_mpi_query
      @user_identity_from_mpi_query ||= UserIdentity.new({ idme_uuid: user_for_mpi_query.idme_uuid,
                                                           logingov_uuid: user_for_mpi_query.logingov_uuid,
                                                           loa: user_for_mpi_query.loa,
                                                           sign_in: sign_in,
                                                           email: credential_email,
                                                           authn_context: authn_context })
    end

    def user_for_mpi_query
      @user_for_mpi_query ||= begin
        user = User.new
        user.instance_variable_set(:@identity, user_identity_from_attributes)
        user.invalidate_mpi_cache
        user
      end
    end

    def user_code_map
      @user_code_map ||= SignIn::UserCodeMap.new(login_code: login_code,
                                                 type: state_payload.type,
                                                 client_state: state_payload.client_state,
                                                 client_id: state_payload.client_id)
    end

    def user_verification
      @user_verification ||= Login::UserVerifier.new(user_for_mpi_query).perform
    end

    def authn_context
      user_attributes[:authn_context]
    end

    def sign_in
      user_attributes[:sign_in]
    end

    def credential_email
      user_attributes[:csp_email]
    end

    def login_code
      @login_code ||= SecureRandom.uuid
    end
  end
end
