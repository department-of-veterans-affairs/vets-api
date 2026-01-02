# frozen_string_literal: true

require 'vets/shared_logging'

module BEP
  class AwardsService
    include Vets::SharedLogging

    attr_reader :participant_id, :ssn, :common_name, :email, :icn

    def initialize(user)
      @participant_id = user.participant_id
      @ssn = user.ssn
      @common_name = user.common_name
      @email = user.email
      @icn = user.icn
    end

    def get_awards
      service.awards.find_award_by_participant_id(participant_id, ssn) || service.awards.find_award_by_ssn(ssn)
    rescue => e
      log_exception_to_sentry(e, { icn: }, { team: Constants::SENTRY_REPORTING_TEAM })

      log_exception_to_rails(e)
      false
    end

    private

    def service
      @service ||= BEP::Services.new(external_uid: icn, external_key:)
    end

    def external_key
      @external_key ||= begin
        key = common_name.presence || email
        key.first(Constants::EXTERNAL_KEY_MAX_LENGTH)
      end
    end
  end
end
