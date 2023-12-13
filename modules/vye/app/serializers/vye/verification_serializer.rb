# frozen_string_literal: true

module Vye; end

class Vye::VerificationSerializer < ActiveModel::Serializer
  attributes :award_id, :change_flag, :act_begin, :act_end, :source_ind
end
