# frozen_string_literal: true

module SignIn
  class StatePayload
    include ActiveModel::Validations

    attr_reader :acr, :client_id, :type, :code_challenge, :client_state, :code, :scope, :created_at, :operation

    validates :code, :created_at, presence: true
    validates :acr, inclusion: Constants::Auth::ACR_VALUES
    validates :type, inclusion: Constants::Auth::CSP_TYPES
    validates :operation, inclusion: Constants::Auth::OPERATION_TYPES, allow_blank: true
    validates :client_state, length: { minimum: Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH }, allow_blank: true

    validate :confirm_client_id

    # rubocop:disable Metrics/ParameterLists
    def initialize(acr:,
                   client_id:,
                   type:,
                   code:,
                   operation:,
                   scope: nil,
                   code_challenge: nil,
                   client_state: nil,
                   created_at: nil)
      @acr = acr
      @client_id = client_id
      @type = type
      @code_challenge = code_challenge
      @client_state = client_state
      @code = code
      @scope = scope
      @created_at = created_at || Time.zone.now.to_i
      @operation = operation

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
