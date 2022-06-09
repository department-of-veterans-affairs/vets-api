# frozen_string_literal: true

module SignIn
  class UserCodeMap
    include ActiveModel::Validations

    attr_reader(
      :login_code,
      :type,
      :client_state,
      :client_id
    )

    validates(:login_code, :type, :client_id, presence: true)

    def initialize(login_code:,
                   type:,
                   client_id:,
                   client_state:)
      @login_code = login_code
      @type = type
      @client_id = client_id
      @client_state = client_state

      validate!
    end

    def persisted?
      false
    end
  end
end
