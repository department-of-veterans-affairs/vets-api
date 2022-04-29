# frozen_string_literal: true

module SignIn
  class UserLoader
    attr_reader :access_token

    def initialize(access_token:)
      @access_token = access_token
    end

    def perform
      find_user || reload_user
    end

    private

    def find_user
      User.find(access_token.user_uuid)
    end

    def reload_user
      validate_account_and_session
      user_identity.uuid = user_uuid
      current_user.uuid = user_uuid
      current_user.last_signed_in = session.created_at
      current_user.save && user_identity.save
      current_user
    end

    def validate_account_and_session
      raise Errors::UserAccountNotFoundError unless user_account
      raise Errors::SessionNotFoundError unless session
    end

    def user_attributes
      {
        mhv_icn: user_account.icn,
        loa: { current: loa, highest: LOA::THREE }
      }
    end

    def loa
      user_account.icn ? LOA::THREE : LOA::ONE
    end

    def user_uuid
      @user_uuid ||= access_token.user_uuid
    end

    def session
      @session ||= OAuthSession.find_by(handle: access_token.session_handle)
    end

    def user_account
      @user_account ||= UserAccount.find_by(id: user_uuid)
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
  end
end
