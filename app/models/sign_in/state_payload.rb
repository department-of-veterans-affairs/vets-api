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
    validates :type, inclusion: Constants::Auth::CSP_TYPES
    validates :client_state, length: { minimum: Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH }, allow_blank: true

    validate :confirm_client_id

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

    private

    def confirm_client_id
      errors.add(:base, 'Client id must map to a configuration') unless ClientConfig.valid_client_id?(client_id:)
    end
  end
end
