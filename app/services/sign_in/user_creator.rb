# frozen_string_literal: true

module SignIn
  class UserCreator
    attr_reader :user_attributes, :state

    def initialize(user_attributes:, state:)
      @user_attributes = user_attributes
      @state = state
    end

    def perform
      check_state_match
      update_and_persist_user
      create_code_container
      login_code
    end

    private

    def update_and_persist_user
      raise SignIn::Errors::UserAttributesMalformedError unless user_verification

      current_user.uuid = user_verification.user_account.id
      user_identity.uuid = user_verification.user_account.id
      current_user.last_signed_in = Time.zone.now
      current_user.save && user_identity.save
    end

    def check_state_match
      raise SignIn::Errors::StateMismatchError unless code_challenge_state_map
    end

    def create_code_container
      SignIn::CodeContainer.new(code: login_code,
                                code_challenge: code_challenge_state_map.code_challenge,
                                user_account_uuid: current_user.uuid).save!
    end

    def code_challenge_state_map
      @code_challenge_state_map ||= SignIn::CodeChallengeStateMap.find(state)
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

    def user_verification
      @user_verification ||= Login::UserVerifier.new(current_user).perform
    end

    def login_code
      @login_code ||= SecureRandom.uuid
    end
  end
end
