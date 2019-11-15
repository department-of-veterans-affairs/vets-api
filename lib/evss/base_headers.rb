# frozen_string_literal: true

module EVSS
  class BaseHeaders
    attr_reader :transaction_id

    def initialize(user)
      @user = user
      @transaction_id = create_transaction_id
    end

    private

    def create_transaction_id
      "vagov-#{SecureRandom.uuid}"
    end

    def iso8601_birth_date
      return nil unless @user&.va_profile&.birth_date

      DateTime.parse(@user.va_profile.birth_date).iso8601
    end
  end
end
