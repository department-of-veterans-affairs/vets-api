# frozen_string_literal: true

module Vye
  class VerificationSerializer < ActiveModel::Serializer
    attributes :award_id, :change_flag, :act_begin, :act_end, :source_ind
  end
end
