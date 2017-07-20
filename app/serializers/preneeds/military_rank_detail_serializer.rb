# frozen_string_literal: true
module Preneeds
  class MilitaryRankDetailSerializer < ActiveModel::Serializer
    attribute :id
    attribute :branch_of_service_code
    attribute :rank_code
    attribute :rank_descr
  end
end
