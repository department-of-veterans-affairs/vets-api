# frozen_string_literal: true

require 'evss/auth_headers'
require 'evss/vso_search/service'

# Veteran model
module Veteran
  class User < Base
    attr_accessor :power_of_attorney

    def initialize(user)
      @user = user
      if json_data && json_data[:person_org_name].present?
        code = json_data[:person_org_name]&.split&.first
        self.power_of_attorney = PowerOfAttorney.new(code: code)
      end
    end

    private

    def json_data
      @json_data ||= bgs_service.claimant.find_poa_by_participant_id(@user.participant_id)
    end

    def bgs_service
      external_key = @user.common_name || @user.email

      @bgs_service ||= BGS::Services.new(
        external_uid: @user.icn,
        external_key: external_key
      )
    end
  end
end
