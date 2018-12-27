# frozen_string_literal: true

require 'common/models/base'

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

  attr_accessor :poa

  def self.from_evss(evss_data)
    evss_data = evss_data.deep_transform_keys { |key| key.to_s.underscore }
    veteran = new(evss_data['info'])
    if evss_data['current_poa'].present?
      veteran.poa = Poa.new(evss_data['current_poa'])
    end
    veteran
  end
end
