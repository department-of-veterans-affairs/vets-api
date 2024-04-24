# frozen_string_literal: true

=begin

  Problem: This job requires a saved_claims_id which
  means that the claim to submit to lighthouse must
  already exist in the database table saved_claims.
  
  A form 4142 is not saved in the database table.  Currently
  it is submitted through central mail as a PDF.  We
  want to drop the central mail service in favor of
  using the lighthouse.

  Task is to create a new JOB which takes a PDF
  and submits it to lighthoust.

  This new JOB will shall several of the methods that
  currently exist in the old JOB.  SO:
    1. Identify the shared methods
    2. Extract them into a library
    3. Include that library in the old JOB and the new JOB
    4. write some new specs.


This is what the Form4142 looks like from the
Form526Submission model which invokes this job:

form[FORM_4142] -=> {"privacyAgreementAccepted"=>true,
 "limitedConsent"=>"true",
 "providerFacility"=>
  [{"providerFacilityName"=>"provider 1",
    "treatmentDateRange"=>
     [{"from"=>"1980-1-1", "to"=>"1985-1-1"},
      {"from"=>"1986-1-1", "to"=>"1987-1-1"}],
    "providerFacilityAddress"=>
     {"street"=>"123 Main Street",
      "street2"=>"1B",
      "city"=>"Baltimore",
      "state"=>"MD",
      "country"=>"USA",
      "postalCode"=>"21200-1111"}},
   {"providerFacilityName"=>"provider 2",
    "treatmentDateRange"=>
     [{"from"=>"1980-2-1", "to"=>"1985-2-1"},
      {"from"=>"1986-2-1", "to"=>"1987-2-1"}],
    "providerFacilityAddress"=>
     {"street"=>"456 Main Street",
      "street2"=>"1B",
      "city"=>"Baltimore",
      "state"=>"MD",
      "country"=>"USA",
      "postalCode"=>"21200-1111"}},
   {"providerFacilityName"=>"provider 3",
    "treatmentDateRange"=>
     [{"from"=>"1980-3-1", "to"=>"1985-3-1"},
      {"from"=>"1986-3-1", "to"=>"1987-3-1"}],
    "providerFacilityAddress"=>
     {"street"=>"789 Main Street",
      "street2"=>"1B",
      "city"=>"Baltimore",
      "state"=>"MD",
      "country"=>"USA",
      "postalCode"=>"21200-1111"}},
   {"providerFacilityName"=>"provider 4",
    "treatmentDateRange"=>
     [{"from"=>"1980-4-1", "to"=>"1985-4-1"},
      {"from"=>"1986-4-1", "to"=>"1987-4-1"}],
    "providerFacilityAddress"=>
     {"street"=>"101 Main Street",
      "street2"=>"1B",
      "city"=>"Baltimore",
      "state"=>"MD",
      "country"=>"USA",
      "postalCode"=>"21200-1111"}},
   {"providerFacilityName"=>"provider 5",
    "treatmentDateRange"=>
     [{"from"=>"1980-5-1", "to"=>"1985-5-1"},
      {"from"=>"1986-5-1", "to"=>"1987-5-1"}],
    "providerFacilityAddress"=>
     {"street"=>"102 Main Street",
      "street2"=>"1B",
      "city"=>"Baltimore",
      "state"=>"MD",
      "country"=>"USA",
      "postalCode"=>"21200-1111"}}],
 "vaFileNumber"=>"796068949",
 "veteranSocialSecurityNumber"=>"796068949",
 "veteranFullName"=>{"first"=>"Beyonce", "middle"=>nil, "last"=>"Knowles"},
 "veteranDateOfBirth"=>"1809-02-12",
 "veteranAddress"=>
  {"city"=>"Portland",
   "country"=>"USA",
   "postalCode"=>"12345-6789",
   "street"=>"1234 Couch Street",
   "street2"=>"Apt. 22",
   "state"=>"OR"},
 "email"=>"test@email.com",
 "veteranPhone"=>"2024561111",
 "veteranServiceNumber"=>""
}


=end


require 'central_mail/service'
require 'central_mail/datestamp_pdf'
require 'pension_burial/tag_sentry'
require 'benefits_intake_service/service'
require 'simple_forms_api_submission/metadata_validator'
require 'pdf_info'

module Lighthouse

  # TODO: review this file: app/sidekiq/central_mail/submit_form4142_job.rb
  #       extract what is need from there and put into here

  class SubmitForm4142Job
    include Sidekiq::Job
    include SentryLogging
    class BenefitsIntakeClaimError < StandardError; end

    FOREIGN_POSTALCODE = '00000'
    STATSD_KEY_PREFIX = 'worker.lighthouse.submit_form4142'

    # Sidekiq has built in exponential back-off functionality for retries
    # A max retry attempt of 14 will result in a run time of ~25 hours
    RETRY = 14

    sidekiq_options retry: RETRY

    sidekiq_retries_exhausted do |msg, _ex|
      Rails.logger.send(
        :error,
        "Failed all retries on Lighthouse::SubmitForm4142Job, last error: #{msg['error_message']}"
      )
      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")
    end


    # form526_submission_id is the ActiveRecord primary
    # key value to the Form526Submission table.
    #
    # This job is kicked-off by the Form526Submission model
    # as part of a workflow batch of jobs to submit all the
    # forms associated with the Form526 package.
    #
    def perform(form526_submission_id)
      # TODO: How do you use the Lighthouse API to submit a
      #       form?  
      # TODO: In the old_perform below, the saved_claim_id
      #       is used to get a SavedClaim model instance.
      #       How does that differ from what is available via
      #       the Form526Submission model?
    end


    # rubocop:disable Metrics/MethodLength
    def old_perform(saved_claim_id)
      @claim            = SavedClaim.find(saved_claim_id)
      @pdf_path         = process_record(@claim)
      
      @attachment_paths = @claim.persistent_attachments.map do |record|
        process_record(record)
      end

      @lighthouse_service = BenefitsIntakeService::Service.new(with_upload_location: true)
      
      create_form_submission_attempt(@lighthouse_service.uuid)

      payload = {
        upload_url:   @lighthouse_service.location,
        file:         split_file_and_path(@pdf_path),
        metadata:     generate_metadata.to_json,
        attachments:  @attachment_paths.map(&method(:split_file_and_path))
      }

      response = @lighthouse_service.upload_doc(**payload)

      if response.success?
        log_message_to_sentry('CentralMail::SubmitSavedClaimJob succeeded', :info, generate_sentry_details)
        @claim.send_confirmation_email if @claim.respond_to?(:send_confirmation_email)
      else
        raise BenefitsIntakeClaimError, response.body
      end
    rescue => e
      log_message_to_sentry('CentralMail::SubmitBenefitsIntakeClaim failed, retrying...', :warn,
                            generate_sentry_details(e))
      raise
    ensure
      cleanup_file_paths
    end


    # rubocop:enable Metrics/MethodLength
    def generate_metadata
      form              = @claim.parsed_form
      veteran_full_name = form['veteranFullName']
      address           = form['claimantAddress'] || form['veteranAddress']

      metadata = {
        'veteranFirstName'  => veteran_full_name['first'],
        'veteranLastName'   => veteran_full_name['last'],
        'fileNumber'        => form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
        'zipCode'           => address['country'] == 'USA' ? address['postalCode'] : FOREIGN_POSTALCODE,
        'source'            => "#{@claim.class} va.gov",
        'docType'           => @claim.form_id,
        'businessLine'      => @claim.business_line
      }

      SimpleFormsApiSubmission::MetadataValidator.validate(metadata)
    end


    def process_record(record)
      pdf_path = record.to_pdf
      stamped_path = CentralMail::DatestampPdf.new(pdf_path).run(text: 'VA.GOV', x: 5, y: 5)
      CentralMail::DatestampPdf.new(stamped_path).run(
        text:       'FDC Reviewed - va.gov Submission',
        x:          429,
        y:          770,
        text_only:  true
      )
    end


    def split_file_and_path(path)
      { file: path, file_name: path.split('/').last }
    end


    #################################################
    private

    def generate_sentry_details(e = nil)
      details = {
        'guid'          => @claim&.guid,
        'docType'       => @claim&.form_id,
        'savedClaimId'  => @saved_claim_id
      }

      details['error'] = e.message if e
      
      details
    end


    def create_form_submission_attempt(intake_uuid)
      form_submission = FormSubmission.create(
        form_type:            @claim.form_id,
        form_data:            @claim.to_json,
        benefits_intake_uuid: intake_uuid,
        saved_claim:          @claim
      )

      @form_submission_attempt = FormSubmissionAttempt.create(form_submission:)
    end


    def cleanup_file_paths
      Common::FileHelpers.delete_file_if_exists(@pdf_path) if @pdf_path
      @attachment_paths&.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
    end
  end
end





__END__

####################################
##   This is the source of the    ##
## CentralMail::SubmitForm4142Job ##
####################################


# frozen_string_literal: true

require 'central_mail/service'
require 'common/exceptions'
require 'evss/disability_compensation_form/metrics'
require 'evss/disability_compensation_form/form4142_processor'
require 'logging/third_party_transaction'

module CentralMail
  class SubmitForm4142Job < EVSS::DisabilityCompensationForm::Job
    extend Logging::ThirdPartyTransaction::MethodWrapper

    # this is required to make instance variables available to logs via
    # the wrap_with_logging method
    attr_accessor :submission_id

    wrap_with_logging(
      :upload_to_central_mail,
      additional_instance_logs: {
        submission_id: [:submission_id]
      }
    )

    STATSD_KEY_PREFIX = 'worker.evss.submit_form4142'

    # Sidekiq has built in exponential back-off functionality for retries
    # A max retry attempt of 10 will result in a run time of ~8 hours
    # This job is invoked from 526 background job, ICMHS is reliable
    # and hence this value is set at a lower value
    RETRY = 10

    sidekiq_options retry: RETRY

    class CentralMailResponseError < Common::Exceptions::BackendServiceException; end

    sidekiq_retries_exhausted do |msg, _ex|
      job_id                = msg['jid']
      error_class           = msg['error_class']
      error_message         = msg['error_message']
      timestamp             = Time.now.utc
      form526_submission_id = msg['args'].first

      form_job_status = Form526JobStatus.find_by(job_id:)
      bgjob_errors = form_job_status.bgjob_errors || {}
      new_error = {
        "#{timestamp.to_i}": {
          caller_method: __method__.to_s,
          error_class:,
          error_message:,
          timestamp:,
          form526_submission_id:
        }
      }

      form_job_status.update(
        status: Form526JobStatus::STATUS[:exhausted],
        bgjob_errors: bgjob_errors.merge(new_error)
      )

      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")

      ::Rails.logger.warn(
        'Submit Form 4142 Retries exhausted',
        { 
          job_id:, 
          error_class:, 
          error_message:, 
          timestamp:, 
          form526_submission_id: 
        }
      )

    rescue => e
      ::Rails.logger.error(
        'Failure in SubmitForm4142#sidekiq_retries_exhausted',
        {
          messaged_content: e.message,
          job_id:,
          submission_id: form526_submission_id,
          pre_exhaustion_failure: {
            error_class:,
            error_message:
          }
        }
      )
      raise e
    end


    # Performs an asynchronous job for submitting a Form 4142 to central mail service
    #
    # @param submission_id [Integer] the {Form526Submission} id
    #
    def perform(submission_id)
      @submission_id = submission_id

      Sentry.set_tags(source: '526EZ-all-claims')
      super(submission_id)

      with_tracking('Form4142 Submission', submission.saved_claim_id, submission.id) do
        @pdf_path = processor.pdf_path
        response  = upload_to_central_mail
        handle_service_exception(response) if response.present? && response.status.between?(201, 600)
      end

    rescue => e
      # Cannot move job straight to dead queue dynamically within an executing job
      # raising error for all the exceptions as sidekiq will then move into dead queue
      # after all retries are exhausted
      retryable_error_handler(e)
      raise e

    ensure
      File.delete(@pdf_path) if @pdf_path.present?
    end


    ##############################################
    private

    def processor
      @processor ||= EVSS::DisabilityCompensationForm::Form4142Processor.new(submission, jid)
    end


    def upload_to_central_mail
      CentralMail::Service.new.upload(processor.request_body)
    end


    # Cannot move job straight to dead queue dynamically within an executing job
    # raising error for all the exceptions as sidekiq will then move into dead queue
    # after all retries are exhausted
    def handle_service_exception(response)
      error = create_service_error(nil, self.class, response)
      raise error
    end


    def create_service_error(key, source, response, _error = nil)
      response_values = response_values(key, source, response.status, response.body)
      CentralMailResponseError.new(key, response_values, nil, nil)
    end


    def response_values(key, source, status, detail)
      {
        status:,
        detail:,
        code:   key,
        source: source.to_s
      }
    end
  end
end


