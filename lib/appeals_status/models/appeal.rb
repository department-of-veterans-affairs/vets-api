# frozen_string_literal: true

require 'appeals_status/models/event'
require 'appeals_status/models/hearing'
require 'common/models/base'

module AppealsStatus
  module Models
    class Appeal < Common::Base
      include Virtus.model
      attribute :id, Integer
      attribute :active, Boolean
      attribute :type, String
      attribute :prior_decision_date, Date
      attribute :requested_hearing_type, String
      attribute :events, Array[AppealsStatus::Models::Event]
      attribute :hearings, Array[AppealsStatus::Models::Hearing]
    end
  end
end
