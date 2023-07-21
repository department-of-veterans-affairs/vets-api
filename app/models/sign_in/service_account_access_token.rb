# frozen_string_literal: true

module SignIn
  class ServiceAccountAccessToken
    include ActiveModel::Validations

    attr_reader(
      :uuid,
      :service_account_id,
      :audience,
      :scopes,
      :user_identifier,
      :version,
      :expiration_time,
      :created_time
    )

    validates(
      :uuid,
      :service_account_id,
      :audience,
      :user_identifier,
      :version,
      :expiration_time,
      :created_time,
      presence: true
    )

    validates :version, inclusion: Constants::AccessToken::VERSION_LIST

    # rubocop:disable Metrics/ParameterLists
    def initialize(service_account_id:,
                   audience:,
                   user_identifier:,
                   scopes: [],
                   uuid: nil,
                   version: nil,
                   expiration_time: nil,
                   created_time: nil)
      @uuid = uuid || create_uuid
      @service_account_id = service_account_id
      @user_identifier = user_identifier
      @scopes = scopes
      @audience = audience
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
        service_account_id:,
        user_identifier:,
        scopes:,
        audience:,
        version:,
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
      service_account_config.access_token_duration
    end

    def service_account_config
      @service_account_config ||= ServiceAccountConfig.find_by(service_account_id:)
    end
  end
end
