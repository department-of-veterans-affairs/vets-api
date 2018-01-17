# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  class MilitaryRankDetail < Common::Base
    attribute :branch_of_service_code, String
    attribute :rank_code, String
    attribute :rank_descr, String

    def id
      branch_of_service_code + ':' + rank_code
    end
  end
end
