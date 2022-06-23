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
      :seed
    )

    validates :code_challenge, :seed, presence: true
    validates :acr, inclusion: Constants::Auth::ACR_VALUES
    validates :client_id, inclusion: Constants::ClientConfig::CLIENT_IDS
    validates :type, inclusion: Constants::Auth::REDIRECT_URLS
    validates :client_state, length: { minimum: Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH }, allow_blank: true

    def initialize(acr:, code_challenge:, client_id:, type:, client_state: nil)
      @acr = acr
      @client_id = client_id
      @type = type
      @code_challenge = code_challenge
      @client_state = client_state
      @seed = create_random_seed

      validate!
    end

    def persisted?
      false
    end

    private

    def create_random_seed
      SecureRandom.hex
    end
  end
end
