# frozen_string_literal: true

Spring.watch 'config/application.yml'
Spring.watch 'config/settings.yml'
Spring.watch 'config/settings.local.yml'

require 'spring/application'

# patches spring to allow the parallel specs gem to use multiple db connections under spring
class Spring::Application
  alias connect_database_orig connect_database

  # Disconnect & reconfigure to pickup DB name with
  # TEST_ENV_NUMBER suffix
  def connect_database
    disconnect_database
    reconfigure_database
    connect_database_orig
  end

  # Here we simply replace existing AR from main spring process
  def reconfigure_database
    if active_record_configured?
      ActiveRecord::Base.configurations =
        Rails.application.config.database_configuration
    end
  end
end
