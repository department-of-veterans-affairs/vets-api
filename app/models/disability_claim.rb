# frozen_string_literal: true
require 'evss/documents_service'

class DisabilityClaim < ActiveRecord::Base
  scope :for_user, ->(user) { where(user_uuid: user.uuid) }
end
