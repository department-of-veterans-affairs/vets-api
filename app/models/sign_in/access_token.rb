# frozen_string_literal: true

module SignIn
  class AccessToken
    include ActiveModel::Validations

    attr_reader(
      :uuid,
      :session_handle,
      :client_id,
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
      :client_id,
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
    validates :client_id, inclusion: Constants::ClientConfig::CLIENT_IDS

    # rubocop:disable Metrics/ParameterLists
    def initialize(session_handle:,
                   client_id:,
                   user_uuid:,
                   refresh_token_hash:,
                   anti_csrf_token:,
                   last_regeneration_time:,
                   uuid: nil,
                   parent_refresh_token_hash: nil,
                   version: nil,
                   expiration_time: nil,
                   created_time: nil)
      @uuid = uuid || create_uuid
      @session_handle = session_handle
      @client_id = client_id
      @user_uuid = user_uuid
      @refresh_token_hash = refresh_token_hash
      @anti_csrf_token = anti_csrf_token
      @last_regeneration_time = last_regeneration_time
      @parent_refresh_token_hash = parent_refresh_token_hash
      @version = version || Constants::AccessToken::CURRENT_VERSION
      @expiration_time = expiration_time || set_expiration_time
      @created_time = created_time || set_created_time

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
      Time.zone.now + validity_length
    end

    def set_created_time
      Time.zone.now
    end

    def validity_length
      if Constants::ClientConfig::SHORT_TOKEN_EXPIRATION.include?(client_id)
        Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES.minutes
      elsif Constants::ClientConfig::LONG_TOKEN_EXPIRATION.include?(client_id)
        Constants::AccessToken::VALIDITY_LENGTH_LONG_MINUTES.minutes
      end
    end
  end
end
