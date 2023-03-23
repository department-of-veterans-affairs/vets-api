# frozen_string_literal: true

require 'common/models/redis_store'

module VANotify
  class ConfirmationEmail < Common::RedisStore
    attribute :user_uuid_and_form_id

    redis_store REDIS_CONFIG[:vanotify_confirmation_email_store][:namespace]
    redis_ttl REDIS_CONFIG[:vanotify_confirmation_email_store][:each_ttl]
    redis_key :user_uuid_and_form_id

    def self.send(email_address:, template_id:, first_name:, user_uuid_and_form_id:)
      return if find(user_uuid_and_form_id)

      create(user_uuid_and_form_id:)
      VANotify::EmailJob.perform_async(
        email_address,
        template_id,
        {
          'first_name' => first_name&.upcase,
          'date' => Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%B %d, %Y')
        }
      )
    end
  end
end
