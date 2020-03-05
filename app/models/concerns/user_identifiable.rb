# frozen_string_literal: true

module UserIdentifiable
  extend ActiveSupport::Concern

  ACCT_ID_PREFIX = 'acct:'

  included do
    # returns all instances that match the given User on their available
    # identifiers, either the users idme uuid or account id
    scope :for_user, ->(u) { where(user_uuid: [ACCT_ID_PREFIX + u.account_id, u.uuid]) }

    # the user_uuid could point to the users id.me uuid or account id, however
    # when we create new instances we would like them to use the account id
    scope :initial_user_uuid, ->(u) { ACCT_ID_PREFIX + u.account_id }
  end
end
