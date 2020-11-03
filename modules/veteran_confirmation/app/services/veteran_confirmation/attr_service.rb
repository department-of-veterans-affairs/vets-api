# frozen_string_literal: true

require 'mpi/attr_service'
require 'mpi/configuration'

module VeteranConfirmation
  class AttrService < MPI::AttrService
    configuration MPI::Configuration
  end
end
