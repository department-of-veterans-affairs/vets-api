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
      update_and_persist_user
      create_code_container
      user_code_map
    end

    private

    def check_and_add_mpi_user
      return unless current_user.loa3? && current_user.icn.nil?

      mpi_response = current_user.mpi_add_person_implicit_search

      raise SignIn::Errors::MPIUserCreationFailedError, 'User MPI record cannot be created' unless mpi_response.ok?

      user_identity.icn = mpi_response.mvi_codes[:icn].presence
    end

    def update_and_persist_user
      raise SignIn::Errors::UserAttributesMalformedError, 'User Attributes are Malformed' unless user_verification

      current_user.uuid = user_verification.user_account.id
      user_identity.uuid = user_verification.user_account.id
      current_user.last_signed_in = Time.zone.now
      current_user.save && user_identity.save
    end

    def create_code_container
      SignIn::CodeContainer.new(code: login_code,
                                client_id: state_payload.client_id,
                                code_challenge: state_payload.code_challenge,
                                user_verification_id: user_verification.id,
                                credential_email: credential_email).save!
    end

    def user_identity
      @user_identity ||= UserIdentity.new(user_attributes)
    end

    def current_user
      return @current_user if @current_user

      user = User.new
      user.instance_variable_set(:@identity, user_identity)
      @current_user = user
    end

    def user_code_map
      @user_code_map ||= SignIn::UserCodeMap.new(login_code: login_code,
                                                 type: state_payload.type,
                                                 client_state: state_payload.client_state,
                                                 client_id: state_payload.client_id)
    end

    def user_verification
      @user_verification ||= Login::UserVerifier.new(current_user).perform
    end

    def credential_email
      user_attributes[:csp_email]
    end

    def login_code
      @login_code ||= SecureRandom.uuid
    end
  end
end
