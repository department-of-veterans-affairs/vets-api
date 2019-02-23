# frozen_string_literal: true

module EventLog
  class Log < ActiveRecord::Base
    self.table_name = 'event_logs'

    after_initialize :initialize_defaults

    private

    def initialize_defaults; end
  end
end
