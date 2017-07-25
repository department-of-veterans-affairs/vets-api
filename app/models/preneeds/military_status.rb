# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class MilitaryStatus < Preneeds::Base
    STATUSES = {
      veteran: 'V',
      retired_active_duty: 'E',
      died_on_active_duty: 'D',
      retired_reserve: 'O',
      death_inactive_duty: 'I',
      other: 'X'
    }.freeze

    attribute :veteran, Boolean
    attribute :retired_active_duty, Boolean
    attribute :died_on_active_duty, Boolean
    attribute :retired_reserve, Boolean
    attribute :death_inactive_duty, Boolean
    attribute :other, Boolean

    def as_eoas
      # false.present? == false
      STATUSES.keys.each_with_object([]) { |key, o| o << STATUSES[key] if self[key].present? }
    end

    def self.permitted_params
      attribute_set.map { |a| a.name.to_sym }
    end
  end
end
