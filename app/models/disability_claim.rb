# frozen_string_literal: true
require 'evss/documents_service'

class DisabilityClaim < ActiveRecord::Base
  attr_accessor :successful_sync

  scope :for_user, ->(user) { where(user_uuid: user.uuid) }
end
