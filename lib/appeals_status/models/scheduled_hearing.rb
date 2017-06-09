# frozen_string_literal: true
require 'common/models/base'

module AppealsStatus
  module Models
    class ScheduledHearing < Common::Base
      include Virtus.model
      attribute :id, String
      attribute :type, String
    end
  end
end
