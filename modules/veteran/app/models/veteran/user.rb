# frozen_string_literal: true

require 'evss/auth_headers'
require 'evss/vso_search/service'

# Veteran model
module Veteran
  class User < Base
    attribute :veteran_name
    attribute :social_security_number
    attribute :indentity_ind
    attribute :index_ind

    attr_accessor :power_of_attorney

    def initialize(user)
      @user = user
      build_from_json(bgs_service.claimant.find_poa_by_participant_id(user.participant_id))
    end

    def build_from_json(json_data)
      json_data = json_data.deep_transform_keys { |key| key.to_s.underscore }
      set_attributes(json_data['info'])
      if json_data['person_organization_code'].present?
        self.power_of_attorney = PowerOfAttorney.new(code: json_data['person_organization_code'])
      end
    end

    private

    # since assign_attributes is not available, do our own mass assignment
    def set_attributes(attributes_hash)
      attributes_hash.each { |key, value| send("#{key}=", value) if respond_to?("#{key}=") }
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
