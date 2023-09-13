# frozen_string_literal: true

require 'logging/third_party_transaction'

module BGS
  class FlashUpdater
    include Sidekiq::Worker
    include SentryLogging

    extend Logging::ThirdPartyTransaction::MethodWrapper

    attr_accessor :submission_id

    wrap_with_logging(
      :add_flashes,
      additional_class_logs: {
        action: 'Begin Flash addition job'
      },
      additional_instance_logs: {
        submission_id: %i[submission_id]
      }
    )

    def perform(submission_id)
      @submission_id = submission_id

      add_flashes
      confirm_flash_addition
    end

    private

    def add_flashes
      flashes.each do |flash_name|
        # NOTE: Assumption that duplicate flashes are ignored when submitted
        service.add_flash(file_number: ssn, flash_name:)
      rescue BGS::ShareError, BGS::PublicError => e
        Raven.tags_context(source: '526EZ-all-claims', submission_id:)
        log_exception_to_sentry(e)
      end
    end

    def confirm_flash_addition
      assigned_flashes = service.find_assigned_flashes(ssn)[:flashes]
      flashes.each do |flash_name|
        assigned_flash = assigned_flashes.find { |af| af[:flash_name].strip == flash_name }
        if assigned_flash.blank?
          Raven.tags_context(source: '526EZ-all-claims', submission_id:)
          e = StandardError.new("Failed to assign '#{flash_name}' to Veteran")
          log_exception_to_sentry(e)
        end
      end
    end

    def flashes
      @flashes ||= submission.form[Form526Submission::FLASHES]
    end

    def submission
      @submission ||= Form526Submission.find(submission_id)
    end

    def ssn
      @ssn ||= submission.auth_headers['va_eauth_pnid']
    end

    def service
      @service ||= bgs_service.claimant
    end

    def bgs_service
      # BGS::Services is in the BGS bgs-ext gem, not to be confused with BGS::Service
      BGS::Services.new(
        external_uid: ssn,
        external_key: ssn
      )
    end
  end
end
