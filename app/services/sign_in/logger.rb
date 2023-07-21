# frozen_string_literal: true

require 'sign_in/constants/auth'

module SignIn
  class Logger
    attr_reader :prefix

    def initialize(prefix:)
      @prefix = prefix
    end

    def info(message, context = {})
      Rails.logger.info("[SignInService] [#{prefix}] #{message}", context)
    end
  end
end
