# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'sm/client_session'
require 'sm/configuration'
require 'vets/collection'

# Predefine Client with correct superclass before loading concerns that reopen it
module SM
  class Client < Common::Client::Base; end
end

# Extracted domain concerns (each reopens SM::Client)
require_relative 'client/concerns/validation_and_auth'
require_relative 'client/concerns/caching'
require_relative 'client/concerns/preferences'
require_relative 'client/concerns/folders'
require_relative 'client/concerns/drafts'
require_relative 'client/concerns/messages'
require_relative 'client/concerns/attachments'
require_relative 'client/concerns/triage_teams'
require_relative 'client/concerns/status_polling'

module SM
  # Secure Messaging API client (public interface). Heavy logic is composed
  # from small concerns to keep this file lean and readable.
  class Client
    include Common::Client::Concerns::MHVSessionBasedClient

    include SM::Client::ValidationAndAuth
    include SM::Client::Caching
    include SM::Client::Preferences
    include SM::Client::Folders
    include SM::Client::Drafts
    include SM::Client::Messages
    include SM::Client::Attachments
    include SM::Client::TriageTeams
    include SM::Client::StatusPolling

    configuration SM::Configuration
    client_session SM::ClientSession

    MHV_MAXIMUM_PER_PAGE = 250
    CONTENT_DISPOSITION  = 'attachment; filename='
    STATSD_KEY_PREFIX    = if instance_of?(SM::Client)
                             'api.sm'
                           else
                             'mobile.sm'
                           end

    # ---- Metrics ---------------------------------------------------------

    def statsd_cache_hit
      StatsD.increment("#{STATSD_KEY_PREFIX}.cache.hit")
    end

    def statsd_cache_miss
      StatsD.increment("#{STATSD_KEY_PREFIX}.cache.miss")
    end

    # Expose polling helpers explicitly (referenced in specs/controllers)
    public :get_message_status, :poll_message_status
  end
end
