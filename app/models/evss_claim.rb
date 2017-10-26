# frozen_string_literal: true
class EVSSClaim < ActiveRecord::Base
  scope :for_user, ->(user) { where(user_uuid: user.uuid) }
end
