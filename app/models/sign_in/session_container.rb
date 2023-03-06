# frozen_string_literal: true

module SignIn
  class SessionContainer
    include ActiveModel::Validations

    attr_reader(
      :session,
      :refresh_token,
      :access_token,
      :anti_csrf_token,
      :client_config
    )

    validates(
      :session,
      :refresh_token,
      :access_token,
      :anti_csrf_token,
      :client_config,
      presence: true
    )

    def initialize(session:,
                   refresh_token:,
                   access_token:,
                   anti_csrf_token:,
                   client_config:)
      @session = session
      @refresh_token = refresh_token
      @access_token = access_token
      @anti_csrf_token = anti_csrf_token
      @client_config = client_config

      validate!
    end

    def persisted?
      false
    end
  end
end
