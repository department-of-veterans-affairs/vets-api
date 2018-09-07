# frozen_string_literal: true

require 'common/client/base'

module Preneeds
  class BurialService < Service
    configuration Preneeds::BurialConfiguration
  end
end
