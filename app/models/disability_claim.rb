# frozen_string_literal: true
require 'evss/documents_service'

class DisabilityClaim < ActiveRecord::Base
  attr_accessor :successful_sync

  scope :for_user, ->(user) { where(user_uuid: user.uuid) }

  def update_evss_data(raw_claim)
    update_attributes(data: raw_claim, successful_sync: true)
    touch # Ensure that updated_at is touched
  end
end
