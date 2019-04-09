# frozen_string_literal: true

require 'common/client/base'

module Preneeds
  # (see Preneeds::Service)
  # Temporary class that utilizes the {Preneeds::LoggedConfiguration} for logging of requests and responses
  #
  class LoggedService < Service
    # Specifies configuration to be used by this service.
    #
    configuration Preneeds::LoggedConfiguration
  end
end
