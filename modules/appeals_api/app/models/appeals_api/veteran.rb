# frozen_string_literal: true

module AppealsApi
  class Veteran
    delegate_missing_to :@veteran

    def initialize(ssn:, first_name:, last_name:, birth_date:)
      @veteran = ClaimsApi::Veteran.new(
        uuid: ssn,
        ssn: ssn,
        first_name: first_name,
        last_name: last_name,
        va_profile: ClaimsApi::Veteran.build_profile(birth_date),
        loa: 3
      )
    end

    private

    attr_reader :veteran
  end
end
