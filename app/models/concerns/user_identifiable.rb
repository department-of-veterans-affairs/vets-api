# frozen_string_literal: true

module UserIdentifiable
  extend ActiveSupport::Concern

  ACCT_ID_PREFIX = 'acct:'

  class_methods do
    # Returns all instances that match the given User on their available
    # identifiers, either the users idme uuid or account id
    def for_user(user)
      where(user_uuid: [ACCT_ID_PREFIX + user.account_id, user.uuid])
    end

    # Return the first instance that matches for the given user + attributes
    # or if none exists, initialize a new instance
    def first_or_initialize_for_user(user, attributes = nil)
      objs = for_user(user).where(attributes || {})
      objs.first_or_initialize(user_uuid: ACCT_ID_PREFIX + user.account_id)
    end
  end
end
