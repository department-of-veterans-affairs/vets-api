# frozen_string_literal: true

require 'gi/client'
require_relative 'configuration'

module GI
  module LCE
    class Client < GI::Client
      configuration GI::LCE::Configuration
    end
  end
end