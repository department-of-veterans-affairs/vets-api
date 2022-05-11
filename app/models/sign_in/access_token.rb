# frozen_string_literal: true

module SignIn
  class AccessToken
    include ActiveModel::Validations

    attr_reader(
      :uuid,
      :session_handle,
      :user_uuid,
      :refresh_token_hash,
      :anti_csrf_token,
      :last_regeneration_time,
      :parent_refresh_token_hash,
      :version,
      :expiration_time,
      :created_time
    )

    validates(
      :uuid,
      :session_handle,
      :user_uuid,
      :refresh_token_hash,
      :anti_csrf_token,
      :last_regeneration_time,
      :version,
      :expiration_time,
      :created_time,
      presence: true
    )

    validates :version, inclusion: Constants::AccessToken::VERSION_LIST

    # rubocop:disable Metrics/ParameterLists
    def initialize(session_handle:, user_uuid:, refresh_token_hash:, anti_csrf_token:, last_regeneration_time:,
                   uuid: create_uuid,
                   parent_refresh_token_hash: nil,
                   version: Constants::AccessToken::CURRENT_VERSION,
                   expiration_time: set_expiration_time,
                   created_time: set_created_time)
      @uuid = uuid
      @session_handle = session_handle
      @user_uuid = user_uuid
      @refresh_token_hash = refresh_token_hash
      @anti_csrf_token = anti_csrf_token
      @last_regeneration_time = last_regeneration_time
      @parent_refresh_token_hash = parent_refresh_token_hash
      @version = version
      @expiration_time = expiration_time
      @created_time = created_time

      validate!
    end
    # rubocop:enable Metrics/ParameterLists

    def persisted?
      false
    end

    private

    def create_uuid
      SecureRandom.uuid
    end

    def set_expiration_time
      Time.zone.now + Constants::AccessToken::VALIDITY_LENGTH_MINUTES.minutes
    end

    def set_created_time
      Time.zone.now
    end
  end
end
