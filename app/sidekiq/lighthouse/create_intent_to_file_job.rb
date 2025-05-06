# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'
require 'lighthouse/benefits_claims/intent_to_file/monitor'

module Lighthouse
  class CreateIntentToFileJob
    include Sidekiq::Job

    attr_reader :form, :itf_type

    class MissingICNError < StandardError; end
    class MissingParticipantIDError < StandardError; end
    class FormNotFoundError < StandardError; end
    class InvalidITFTypeError < StandardError; end

    # Only pension form configured to create async ITFs for now
    ITF_FORMS = {
      # '21-526EZ' => 'compensation',
      # '21P-530EZ' => 'survivor',
      '21P-527EZ' => 'pension'
    }.freeze

    # retry for 2d 1h 47m 12s
    # exhausted attempts will be logged in intent_to_file_queue_exhaustions table
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    sidekiq_options retry: 16, queue: 'low'
    sidekiq_retries_exhausted do |msg, error|
      ::Rails.logger.info("Create Intent to File Job exhausted all retries for in_progress_form_id: #{msg['args'][0]}")

      in_progress_form_id, veteran_icn = msg['args']
      in_progress_form = InProgressForm.find(in_progress_form_id)

      form_type = in_progress_form&.form_id
      itf_type = ITF_FORMS[form_type]

      monitor = BenefitsClaims::IntentToFile::Monitor.new
      monitor.track_create_itf_exhaustion(itf_type, in_progress_form, error)

      # create ITF queue exhaustion entry
      exhaustion = IntentToFileQueueExhaustion.create({
                                                        form_type:,
                                                        form_start_date: in_progress_form&.created_at,
                                                        veteran_icn:
                                                      })
      ::Rails.logger.info(
        "IntentToFileQueueExhaustion id: #{exhaustion&.id} entry created", {
          intent_to_file_queue_exhaustion: exhaustion
        }
      )
    end

    # Create an Intent to File using the Lighthouse ITF endpoint for given in progress form, ICN, and PID
    # On success/failure log and increment the respective Datadog counter
    # @see BenefitsClaims::Service#get_intent_to_file
    # @see BenefitsClaims::Service#create_intent_to_file
    #
    # @param in_progress_form_id [Integer]
    # @param veteran_icn [String] veteran's ICN
    # @param participant_id [String] veteran's participant ID
    #
    # @return [Hash] 'data' response from BenefitsClaims::Service
    def perform(in_progress_form_id, veteran_icn, participant_id)
      init(in_progress_form_id, veteran_icn, participant_id)

      service = BenefitsClaims::Service.new(veteran_icn)
      begin
        itf_found = service.get_intent_to_file(itf_type)
        if itf_found&.dig('data', 'attributes', 'status') == 'active'
          monitor.track_create_itf_active_found(itf_type, form&.created_at&.to_s, form&.user_account_id, itf_found)
          return itf_found
        end
      rescue Common::Exceptions::ResourceNotFound
        # do nothing, continue with creation
      end

      monitor.track_create_itf_begun(itf_type, form&.created_at&.to_s, form&.user_account_id)

      itf_created = service.create_intent_to_file(itf_type, '')

      monitor.track_create_itf_success(itf_type, form&.created_at&.to_s, form&.user_account_id)
      itf_created
    rescue => e
      triage_rescued_error(e)
    end

    private

    # Instantiate instance variables for _this_ job
    #
    # @param (see #perform)
    def init(in_progress_form_id, veteran_icn, participant_id)
      raise MissingICNError, 'Init failed. No veteran ICN provided' if veteran_icn.blank?
      raise MissingParticipantIDError, 'Init failed. No veteran participant ID provided' if participant_id.blank?

      @form = InProgressForm.find(in_progress_form_id)
      raise FormNotFoundError, 'Init failed. Form not found for given ID' if form.blank?

      @itf_type = ITF_FORMS[form&.form_id]
      if form.user_account.blank? || form.user_account&.icn != veteran_icn
        raise ActiveRecord::RecordNotFound, 'Init failed. User account not found for given veteran ICN'
      end

      raise InvalidITFTypeError, 'Init failed. Form type not supported for auto ITF' if itf_type.blank?
    end

    # Track error, prevent retry if will result in known failure, raise again otherwise
    #
    # @param exception [Exception] error thrown within #perform
    def triage_rescued_error(exception)
      if exception.instance_of?(MissingICNError)
        monitor.track_missing_user_icn(form, exception)
      elsif exception.instance_of?(MissingParticipantIDError)
        monitor.track_missing_user_pid(form, exception)
      elsif exception.instance_of?(InvalidITFTypeError)
        monitor.track_invalid_itf_type(form, exception)
      elsif exception.instance_of?(FormNotFoundError)
        monitor.track_missing_form(form, exception)
      else
        monitor.track_create_itf_failure(itf_type, form&.created_at&.to_s, form&.user_account_id, exception)
        raise exception
      end
    end

    # retreive a monitor for tracking
    #
    # @return [BenefitsClaims::IntentToFile::Monitor]
    def monitor
      @monitor ||= BenefitsClaims::IntentToFile::Monitor.new
    end
  end
end
