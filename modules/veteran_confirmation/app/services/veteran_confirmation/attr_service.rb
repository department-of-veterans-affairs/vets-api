# frozen_string_literal: true

require 'mpi/attr_service'
require 'mpi/configuration'

module VeteranConfirmation
  class AttrService < MVI::AttrService
    configuration MVI::Configuration
  end
end
