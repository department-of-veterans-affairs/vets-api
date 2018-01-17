# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  class BranchesOfService < Common::Base
    attribute :code, String
    attribute :flat_full_descr, String
    attribute :full_descr, String
    attribute :short_descr, String
    attribute :upright_full_descr, String

    attribute :begin_date, Common::UTCTime
    attribute :end_date, Common::UTCTime
    attribute :state_required, String

    def id
      code
    end

    # Default sort should be by full_descr ascending
    def <=>(other)
      full_descr <=> other.full_descr
    end
  end
end
