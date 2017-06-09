# frozen_string_literal: true
require 'common/models/base'
require 'appeals_status/models/scheduled_hearing'

module AppealsStatus
  module Models
    class ScheduledHearings < Common::Base
      include Virtus.model
      attribute :data, Array[AppealsStatus::Models::ScheduledHearing]
    end
  end
end
