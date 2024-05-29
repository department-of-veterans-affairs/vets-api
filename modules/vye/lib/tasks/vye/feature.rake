# frozen_string_literal: true

namespace :vye do
  namespace :feature do
    desc 'Enables request_allowed feature flag'
    task request_allowed: :environment do |_cmd, _args|
      current_state = Flipper.enabled?(:vye_request_allowed)
      puts format('Current state vye_request_allowed is: %<current_state>s', current_state:)
      Flipper.enable :vye_request_allowed
    end
  end
end
