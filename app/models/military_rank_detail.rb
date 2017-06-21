# frozen_string_literal: true
require 'common/models/base'

# Military Rank details
class MilitaryRankDetail < Common::Base
  include ActiveModel::Validations

  validates :branch_of_service_code, :rank_code, :rank_descr, presence: true

  attribute :branch_of_service_code, String
  attribute :rank_code, String
  attribute :rank_descr, String

  def id
    branch_of_service_code + ':' + rank_code
  end
end
