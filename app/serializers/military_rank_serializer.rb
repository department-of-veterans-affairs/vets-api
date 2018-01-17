# frozen_string_literal: true

class MilitaryRankSerializer < ActiveModel::Serializer
  attribute :id
  attribute :branch_of_service_cd
  attribute :officer_ind
  attribute :activated_one_date
  attribute :activated_two_date
  attribute :activated_three_date
  attribute :deactivated_one_date
  attribute :deactivated_two_date
  attribute :deactivated_three_date
  attribute :military_rank_detail
end
