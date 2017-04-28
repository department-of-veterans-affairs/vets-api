# frozen_string_literal: true
require 'common/models/base'

module AppealsStatus
  module Models
    class Hearing < Common::Base
      include Virtus.model

      attribute :requested, Boolean
      attribute :scheduled, Boolean
      attribute :date, Date
    end
  end
end
