# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class MilitaryRank < Common::Base
    include ActiveModel::Validations

    validates :branch_of_service_cd, :military_rank_detail, presence: true

    attribute :branch_of_service_cd, String
    attribute :officer_ind, String

    attribute :military_rank_detail, MilitaryRankDetail

    attribute :activated_one_date, String
    attribute :activated_two_date, String
    attribute :activated_three_date, String
    attribute :deactivated_one_date, String
    attribute :deactivated_two_date, String
    attribute :deactivated_three_date, String

    def id
      branch_of_service_cd + ':' + rank_code
    end

    def <=>(other)
      id <=> other.id
    end

    def rank_code
      military_rank_detail[:rank_code]
    end

    def branch_of_service_code
      military_rank_detail[:branch_of_service_code]
    end

    def rank_descr
      military_rank_detail[:rank_descr]
    end
  end
end
