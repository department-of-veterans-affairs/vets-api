# frozen_string_literal: true

module SignIn
  class SessionContainer
    include ActiveModel::Validations

    attr_reader(
      :session,
      :refresh_token,
      :access_token,
      :anti_csrf_token,
      :client_id
    )

    validates(
      :session,
      :refresh_token,
      :access_token,
      :anti_csrf_token,
      :client_id,
      presence: true
    )

    def initialize(session:,
                   refresh_token:,
                   access_token:,
                   anti_csrf_token:,
                   client_id:)
      @session = session
      @refresh_token = refresh_token
      @access_token = access_token
      @anti_csrf_token = anti_csrf_token
      @client_id = client_id

      validate!
    end

    def persisted?
      false
    end
  end
end
