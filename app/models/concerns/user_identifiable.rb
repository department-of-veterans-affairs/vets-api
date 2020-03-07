# frozen_string_literal: true

module UserIdentifiable
  extend ActiveSupport::Concern

  ACCT_ID_PREFIX = 'acct:'

  def user_match(user)
    [ACCT_ID_PREFIX + user.account_id, user.uuid].include?(user_uuid)
  end

  class_methods do
    def for_user(user)
      # returns all instances that match the given User on their available
      # identifiers, either the users idme uuid or account id
      where(user_uuid: [ACCT_ID_PREFIX + user.account_id, user.uuid])
    end

    def first_or_initialize_for_user(user, attributes = nil)
      objs = for_user(user).where(attributes || {})
      objs.first_or_initialize(user_uuid: ACCT_ID_PREFIX + user.account_id)
    end
  end
end
