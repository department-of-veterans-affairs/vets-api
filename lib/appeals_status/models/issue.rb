# frozen_string_literal: true
require 'common/models/base'

module AppealsStatus
  module Models
    class Issue < Common::Base
      include Virtus.model

      attribute :program_area, String
      attribute :type, String
      attribute :rating_requested, String
      attribute :decision, String
    end
  end
end
