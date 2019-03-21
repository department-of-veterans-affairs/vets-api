# frozen_string_literal: true

# Veteran model
module Veteran
  class User < Base
    attribute :veteran_name
    attribute :user_poa_info_available
    attribute :can_be_validated_by_group_one
    attribute :award_suspendbadaddress_indicator
    attribute :award_suspend_indicator
    attribute :social_security_number
    attribute :fiduciary_ind
    attribute :has_payment
    attribute :incompetent_ind
    attribute :indentity_ind
    attribute :index_ind

    attr_accessor :power_of_attorney

    def initialize(user)
      @user = user
      build_from_json(EVSS::VsoSearch::Service.new(user).get_current_info(auth_headers))
    end

    def build_from_json(json_data)
      json_data = json_data.deep_transform_keys { |key| key.to_s.underscore }
      set_attributes(json_data['info'])
      self.power_of_attorney = PowerOfAttorney.new(json_data['current_poa']) if json_data['current_poa'].present?
    end

    private

    # since assign_attributes is not available, do our own mass assignment
    def set_attributes(attributes_hash)
      attributes_hash.each { |key, value| send("#{key}=", value) if respond_to?("#{key}=") }
    end

    def auth_headers
      @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
    end
  end
end
