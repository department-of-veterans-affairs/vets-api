# frozen_string_literal: true

# tricky bit of code that removes existing subcribers
def unsubscribe(log_subscriber, event_component)
  ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
    case subscriber
    when log_subscriber
      puts "Bill Size = #{ActiveSupport::Notifications.notifier.listeners_for(event_component).size}"
      #puts "#{subscriber}"
      ActiveSupport::Notifications.notifier.listeners_for(event_component).each do |listener|
        #puts "#{listener} : #{listener.instance_variable_get('@delegate')}"
        if listener.instance_variable_get('@delegate') == subscriber
          puts "REEEMIVOING! : #{listener}"
          #ActiveSupport::Notifications.unsubscribe listener
        end
      end
    end
  end
end

# The default ActionController::LogSubscriber prints our token
# (see https://github.com/rails/rails/blob/v4.2.7.1/actionpack/lib/action_controller/log_subscriber.rb#L41)
# This class extends
SAML_CONFIG = Rails.application.config_for(:saml).freeze
class FilteredLogSubscriber < ActiveSupport::LogSubscriber
  def redirect_to(event)
    if event.payload[:location].include?(SAML_CONFIG['relay'] + '?token=')
      info { "Redirected to #{SAML_CONFIG['relay']} with token" }
    else
      info { "Redirected to #{event.payload[:location]}" }
    end
  end
end
#FilteredLogSubscriber.attach_to :action_controller
#puts "BEFORE : #{ActiveSupport::LogSubscriber.log_subscribers}"
#unsubscribe(ActionController::LogSubscriber, 'redirect_to.action_controller')
#unsubscribe(ActionController::LogSubscriber, 'unpermitted_parameters.action_controller')
#puts "AFTER  : #{ActiveSupport::LogSubscriber.log_subscribers}"