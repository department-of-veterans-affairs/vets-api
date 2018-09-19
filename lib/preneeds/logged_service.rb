# frozen_string_literal: true

require 'common/client/base'

module Preneeds
  class LoggedService < Service
    configuration Preneeds::LoggedConfiguration
  end
end
