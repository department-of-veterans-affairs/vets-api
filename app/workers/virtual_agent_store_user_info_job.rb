# frozen_string_literal: true

class VirtualAgentStoreUserInfoJob
  include Sidekiq::Worker

  def perform(user_info, action_type, kms, _meta)
    user_record =
      VirtualAgentUserAccessRecord.create(
        action_type: action_type, first_name: user_info['first_name'],
        last_name: user_info['last_name'], ssn: kms.decrypt(user_info['ssn']), icn: user_info['icn']
      )
    user_record.save
  end
end
