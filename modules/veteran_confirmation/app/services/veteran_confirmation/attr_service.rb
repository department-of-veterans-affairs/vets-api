# frozen_string_literal: true

require 'mvi/attr_service'
require 'mvi/configuration'

module VeteranConfirmation
  class AttrService < MVI::AttrService
    configuration MVI::Configuration
  end
end
