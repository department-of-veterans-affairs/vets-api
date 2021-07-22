# frozen_string_literal: true

# add registrations here:
require './modules/vba_documents/lib/vba_documents/webhooks_registrations'

# Sample registration:
# Make sure all exceptions are handled (This is critical). If you let it leak, we default to one hour from now.
#  The do..end block is run over and over to determine the next run.
# last_time_async_scheduled is the last time the async call was made to do the batch notification.
# last_time_async_scheduled always reverts to nil with each deploy.
#
#     register_events("gov.va.developer.benefits-intake.status_change",
#                     "gov.va.developer.benefits-intake.status_change2",
#                      api_name: "PLAY_API", max_retries: 3) do |last_time_async_scheduled|
#       next_run = nil
#       if last_time_async_scheduled.nil?
#         next_run = 0.seconds.from_now
#       else
#         next_run = 5.seconds.from_now
#       end
#       next_run
#     rescue
#       5.seconds.from_now
#     end
#
