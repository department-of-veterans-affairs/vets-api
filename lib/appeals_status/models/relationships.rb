# frozen_string_literal: true
require 'common/models/base'
require 'appeals_status/models/scheduled_hearings'

module AppealsStatus
  module Models
    class Relationships < Common::Base
      include Virtus.model
      attribute :scheduled_hearings, AppealsStatus::Models::ScheduledHearings
    end
  end
end
