# frozen_string_literal: true

module Vye
  class AwardSerializer < ActiveModel::Serializer
    attributes :id,
               :cur_award_ind,
               :award_begin_date,
               :award_end_date,
               :training_time,
               :payment_date,
               :monthly_rate,
               :begin_rsn,
               :end_rsn,
               :type_training,
               :number_hours,
               :type_hours
  end
end
