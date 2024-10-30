# frozen_string_literal: true

require 'gi/configuration'

module GI
  module Lce
    class Configuration < GI::Configuration
      def use_mocks?
        Settings.gids.lce.use_mocks || false
      end
    end
  end
end
