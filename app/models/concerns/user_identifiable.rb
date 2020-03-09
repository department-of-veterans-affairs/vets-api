# frozen_string_literal: true

module UserIdentifiable
  extend ActiveSupport::Concern

  ACCT_ID_PREFIX = 'acct:'

  def user_match(user)
    [ACCT_ID_PREFIX + user.account_id, user.uuid].include?(user_uuid)
  end

  included do
    # Returns all instances that match the given User on their available
    # identifiers, either the users idme uuid or account id
    scope :for_user, ->(u) { where(user_uuid: [ACCT_ID_PREFIX + u.account_id, u.uuid]) }

    # Return the first instance that matches for the given user, or if none
    # exists, initialize a new instance with the given default values
    scope :first_or_initialize_for_user, lambda { |user, defaults = {}|
      for_user(user)
        .first_or_initialize(user_uuid: ACCT_ID_PREFIX + user.account_id, **defaults)
    }
  end
end
