# frozen_string_literal: true

module EventLog
  class EventLog < ActiveRecord::Base
    after_initialize :initialize_defaults

    private

    def initialize_defaults; end
  end
end
