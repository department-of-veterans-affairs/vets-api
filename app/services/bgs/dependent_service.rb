# frozen_string_literal: true

module BGS
  class DependentService < Base
    def initialize(user)
      @user = user
    end

    def get_dependents
      service
        .claimants
        .find_dependents_by_participant_id(
          @user.participant_id, @user.ssn
        )
    end

    private

    def service
      external_key = @user.common_name || @user.email

      @service ||= LighthouseBGS::Services.new(
        external_uid: @user.icn,
        external_key: external_key
      )
    end
  end
end

