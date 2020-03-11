# frozen_string_literal: true

module UserIdentifiable
  extend ActiveSupport::Concern

  ACCT_ID_PREFIX = 'acct:'

  def user_match(user)
    [self.class.default_user_uuid(user), user.uuid].include?(user_uuid)
  end

  included do
    # Returns all instances that match the given User on their available
    # identifiers, either the users idme uuid or account id
    scope :for_user, ->(u) { where(user_uuid: [default_user_uuid(u), u.uuid]) }

    # Return the first instance that matches for the given user, or if none
    # exists, initialize a new instance with the given default values
    scope :first_or_initialize_for_user, lambda { |user, defaults = {}|
      for_user(user)
        .first_or_initialize(user_uuid: default_user_uuid(user), **defaults)
    }
  end

  class_methods do
    def default_user_uuid(user)
      ACCT_ID_PREFIX + user.account_uuid
    end
  end
end
