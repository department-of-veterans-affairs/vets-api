# frozen_string_literal: true

require 'common/models/base'
require 'evss/auth_headers'

# Veteran model
class Veteran < Common::Base
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
    client = EVSS::CommonService.new(auth_headers)
    build_from_json(client.get_current_info)
  end

  def build_from_json(json_data)
    json_data = json_data.deep_transform_keys { |key| key.to_s.underscore }
    json_data['info'].each { |key, value| send("#{key}=", value) if respond_to?("#{key}=") }
    self.power_of_attorney = PowerOfAttorney.new(json_data['current_poa']) if json_data['current_poa'].present?
  end

  private

  def auth_headers
    @auth_headers ||= EVSS::AuthHeaders.new(@user).to_h
  end
end
