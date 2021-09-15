# frozen_string_literal: true

module CheckIn
  class CheckInWithAuth < PatientCheckIn
    LAST_FOUR_REGEX = /^[0-9]{4}$/.freeze
    LAST_NAME_REGEX = /^.{1,600}$/.freeze

    attr_reader :last4, :last_name

    def self.build(opts = {})
      new(opts)
    end

    def initialize(opts)
      @uuid = opts.dig(:data, :uuid)
      @last4 = opts.dig(:data, :last4)
      @last_name = opts.dig(:data, :last_name)
    end

    def valid?
      UUID_REGEX.match?(uuid) && LAST_FOUR_REGEX.match?(last4) && LAST_NAME_REGEX.match?(last_name)
    end

    def client_error
      body = { error: true, message: 'Invalid uuid, last4 or last name!' }

      Faraday::Response.new(body: body, status: 400)
    end
  end
end
