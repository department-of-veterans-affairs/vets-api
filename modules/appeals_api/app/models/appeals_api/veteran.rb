# frozen_string_literal: true

module AppealsApi
  class Veteran
    delegate_missing_to :@veteran

    def initialize(ssn:, first_name:, last_name:, birth_date:)
      @veteran = ClaimsApi::Veteran.new(
        uuid: ssn,
        ssn:,
        first_name:,
        last_name:,
        va_profile: ClaimsApi::Veteran.build_profile(birth_date),
        loa: { current: 3, highest: 3 }
      )
    end

    private

    attr_reader :veteran
  end
end
