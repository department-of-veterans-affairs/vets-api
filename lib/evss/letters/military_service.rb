# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module Letters
    class MilitaryService < Common::Base
      attribute :branch, String
      attribute :character_of_service, String
      attribute :entered_date, DateTime
      attribute :released_date, DateTime
    end
  end
end
