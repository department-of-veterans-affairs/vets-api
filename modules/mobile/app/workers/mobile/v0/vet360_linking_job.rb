# frozen_string_literal: true

require 'sidekiq'
require 'va_profile/person/service'

# This job is run when a user does not have a vet360_id, which indicates that the user does not have an account on the
# VAProfile service. The mobile app depends on the VAProfile service for user contact data, and mobile features
# involving contact data will not work if the user does not have a VAProfile account. This job sends the VAProfile
# service a request to create a profile for the user so that they will have access to more mobile app features. Those
# features will probably not be available until the next time the mobile app requests the user data.
#
# The log outputs from this job seem to mostly come in batches, which may indicate that a lack of vet360_id can also
# occur as a result of some other issue, such as an upstream service being down. We should keep an eye on this.
#
# Success for this job indicates that a request to create an account for the user was successfully received. It does not
# indicate that the account was successfully created.

module Mobile
  module V0
    class Vet360LinkingJob
      include Sidekiq::Worker

      sidekiq_options(retry: false)

      class MissingUserError < StandardError; end

      def perform(uuid)
        user = IAMUser.find(uuid) || User.find(uuid)
        raise MissingUserError, uuid unless user

        result = VAProfile::Person::Service.new(user).init_vet360_id
        Rails.logger.info('Mobile Vet360 account linking request succeeded for user with uuid',
                          { user_uuid: uuid, transaction_id: result.transaction.id })
      rescue => e
        Rails.logger.error('Mobile Vet360 account linking request failed for user with uuid',
                           { user_uuid: uuid, message: e.message })
        raise e
      end
    end
  end
end
