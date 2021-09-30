# frozen_string_literal: true

module ClaimsApi
  class IntentToFile
    attr_reader :id, :creation_date, :expiration_date, :status, :type

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

    SUBMITTER_CODE = 'VETS.GOV'

    def initialize(id:, creation_date:, expiration_date:, status:, type:)
      @id = id
      @creation_date = creation_date
      @expiration_date = expiration_date
      @status = status.downcase if status.is_a? String
      @type = BGS_TYPES_TO_ITF_TYPES[type]
    end

    def active?
      status.casecmp?('active') && expiration_date.to_datetime > Time.zone.now
    end
  end
end
