# frozen_string_literal: true

module SignIn
  class StatePayloadVerifier
    attr_reader :state_payload

    def initialize(state_payload:)
      @state_payload = state_payload
    end

    def perform
      validate_state_code
    end

    private

    def state_code
      @state_code ||= StateCode.find(state_payload.code)
    end

    def validate_state_code
      raise Errors::StateCodeInvalidError.new message: 'Code in state is not valid' unless state_code
    ensure
      state_code&.destroy
    end
  end
end
