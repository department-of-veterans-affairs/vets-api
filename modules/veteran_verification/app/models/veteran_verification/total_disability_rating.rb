# frozen_string_literal: true

require 'active_support/core_ext/digest/uuid'

module VeteranVerification
  class ServiceHistoryEpisode
    include ActiveModel::Serialization
    include Virtus.model

    attribute :disability_rating_record, DisabilityRatingRecord

  end
end

