# frozen_string_literal: true

# 08/08/2022
# The database table backing this model only exists so that we can provide daily
# success/failure reporting on the number of ITFs submitted to BGS.
# If we find in the future that we need to store off consumer submissions in order
# to asynchronously submit them to BGS, the existing model and database table should
# be easily adapted.
module ClaimsApi
  class IntentToFile < ApplicationRecord
    validates :status, presence: true
    validates :cid, presence: true

    SUBMITTED = 'submitted'
    ERRORED = 'errored'
    ALL_STATUSES = [SUBMITTED, ERRORED].freeze
    SUBMITTER_CODE = 'LH-B'

    ITF_TYPES_TO_BGS_TYPES = {
      'compensation' => 'C',
      'burial' => 'S',
      'pension' => 'P'
    }.freeze

    BGS_TYPES_TO_ITF_TYPES = {
      'C' => 'compensation',
      'S' => 'burial',
      'P' => 'pension'
    }.freeze
  end
end
