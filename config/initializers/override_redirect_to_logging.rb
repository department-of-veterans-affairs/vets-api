# frozen_string_literal: true

require 'action_controller/log_subscriber'

# tricky bit of code that removes existing subcribers
def unsubscribe(log_subscriber, event_component)
  ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
    case subscriber
    when log_subscriber
      ActiveSupport::Notifications.notifier.listeners_for(event_component).each do |listener|
        ActiveSupport::Notifications.unsubscribe listener if listener.instance_variable_get('@delegate') == subscriber
      end
    end
  end
end

# Add our custom log subscriber for redirect_to
class FilteredLogSubscriber < ActiveSupport::LogSubscriber
  def redirect_to(event)
    # matches everything up to '?token='
    tokenless_url = /.+\?token=/.match(event.payload[:location]).to_s
    if tokenless_url.blank?
      info { "Redirected to #{event.payload[:location]}" }
    else
      info { "Redirected to #{tokenless_url}[FILTERED]" }
    end
  end
end
FilteredLogSubscriber.attach_to :action_controller

# Remove default LogSubscriber for redirect_to
# see: https://github.com/rails/rails/blob/v4.2.7.1/actionpack/lib/action_controller/log_subscriber.rb#L41
unsubscribe(ActionController::LogSubscriber, 'redirect_to.action_controller')
