# frozen_string_literal: true
require 'appeals_status/models/appeal'
require 'common/models/base'

module AppealsStatus
  module Models
    class Appeals < Common::Base
      include Virtus.model
      attribute :appeals, Array[AppealsStatus::Models::Appeal]
    end
  end
end
