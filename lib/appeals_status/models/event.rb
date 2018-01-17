# frozen_string_literal: true

require 'common/models/base'

module AppealsStatus
  module Models
    class Event < Common::Base
      include Virtus.model
      attribute :type, String
      attribute :date, Date
    end
  end
end
