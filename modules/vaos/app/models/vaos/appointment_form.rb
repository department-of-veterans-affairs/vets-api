# frozen_string_literal: true

require 'active_model'
require 'common/models/form'

module VAOS
  class AppointmentForm < Common::Form
    attribute :email, String
    # TODO others...

    def initialize(user, json_hash)
      @user = user
    end
  end
end
