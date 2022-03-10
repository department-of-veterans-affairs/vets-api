# frozen_string_literal: true

module SignIn
  class SessionContainer
    include ActiveModel::Validations

    attr_reader(
      :session,
      :refresh_token,
      :access_token,
      :anti_csrf_token
    )

    validates(
      :session,
      :refresh_token,
      :access_token,
      :anti_csrf_token,
      presence: true
    )

    def initialize(session:,
                   refresh_token:,
                   access_token:,
                   anti_csrf_token:)
      @session = session
      @refresh_token = refresh_token
      @access_token = access_token
      @anti_csrf_token = anti_csrf_token

      validate!
    end

    def persisted?
      false
    end
  end
end
