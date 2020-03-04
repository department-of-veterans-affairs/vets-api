# frozen_string_literal: true

module UserIdentifiable
  extend ActiveSupport::Concern

  ACCT_ID_PREFIX = 'acct:'

  included do
    # returns all instances that match the given User on their available
    # identifiers, either the users idme uuid or account id
    scope :for_user, ->(u) { where(user_uuid: [u.uuid, ACCT_ID_PREFIX + u.account_id]) }
  end
end
