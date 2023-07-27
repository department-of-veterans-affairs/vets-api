# frozen_string_literal: true

module SignIn
  class AccessToken
    include ActiveModel::Validations

    attr_reader(
      :uuid,
      :session_handle,
      :client_id,
      :user_uuid,
      :audience,
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
      :audience,
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
    def initialize(session_handle:,
                   client_id:,
                   user_uuid:,
                   audience:,
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
      @audience = audience
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

    def to_s
      {
        uuid:,
        user_uuid:,
        session_handle:,
        client_id:,
        audience:,
        version:,
        last_regeneration_time: last_regeneration_time.to_i,
        created_time: created_time.to_i,
        expiration_time: expiration_time.to_i
      }
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
      client_config.access_token_duration
    end

    def client_config
      @client_config ||= ClientConfig.find_by(client_id:)
    end
  end
end
