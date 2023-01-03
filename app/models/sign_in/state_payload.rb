# frozen_string_literal: true

module SignIn
  class StatePayload
    include ActiveModel::Validations

    attr_reader(
      :acr,
      :client_id,
      :type,
      :code_challenge,
      :client_state,
      :code
    )

    validates :code_challenge, :code, presence: true
    validates :acr, inclusion: Constants::Auth::ACR_VALUES
    validates :client_id, inclusion: Constants::Auth::CLIENT_IDS
    validates :type, inclusion: Constants::Auth::CSP_TYPES
    validates :client_state, length: { minimum: Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH }, allow_blank: true

    # rubocop:disable Metrics/ParameterLists
    def initialize(acr:, code_challenge:, client_id:, type:, code:, client_state: nil)
      @acr = acr
      @client_id = client_id
      @type = type
      @code_challenge = code_challenge
      @client_state = client_state
      @code = code

      validate!
    end
    # rubocop:enable Metrics/ParameterLists

    def persisted?
      false
    end
  end
end
