# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'evss/disability_compensation_auth_headers'
require 'evss/disability_compensation_form/form4142'
require 'evss/disability_compensation_form/service'
require 'form526_backup_submission/service'
require 'decision_review_v1/utilities/form_4142_processor'
require 'central_mail/datestamp_pdf'
require 'pdf_fill/filler'

module Sidekiq
  module Form526BackupSubmissionProcess
    class Processor
      attr_reader :submission, :lighthouse_service, :zip, :initial_upload_location, :initial_upload_uuid,
                  :initial_upload
      attr_accessor :docs

      FORM_526 = 'form526'
      FORM_526_DOC_TYPE = '21-526EZ'
      FORM_526_UPLOADS = 'form526_uploads'
      FORM_526_UPLOADS_DOC_TYPE = 'evidence'
      FORM_4142 = 'form4142'
      FORM_4142_DOC_TYPE = '21-4142'
      FORM_0781 = 'form0781'
      FORM_8940 = 'form8940'
      FLASHES = 'flashes'
      BIRLS_KEY = 'va_eauth_birlsfilenumber'
      TMP_FILE_PREFIX = 'form526.backup.'
      EVIDENCE_LOOKUP = {}.freeze
      BKUP_SETTINGS = Settings.key?(:form526_backup) ? Settings.form526_backup : OpenStruct.new

      SUB_METHOD = (BKUP_SETTINGS.submission_method || 'single').to_sym
      CONSUMER_NAME = 'vets_api_backup_submission'

      # Takes a submission id, assembles all needed docs from its payload, then sends it to central mail via
      # lighthouse benefits intake API - https://developer.va.gov/explore/benefits/docs/benefits?version=current
      def initialize(submission_id, docs = [])
        @submission = Form526Submission.find(submission_id)
        @docs = docs
        @lighthouse_service = Form526BackupSubmission::Service.new
        # We need an initial location/uuid as other ancillary docs want a reference id to it
        # (eventhough I dont think they actually use it for anything because we are just using them to
        # generate the pdf and not the sending portion of those classes... but it needs something there to not error)
        @initial_upload = get_upload_info
        uuid_and_location = upload_location_to_location_and_uuid(initial_upload)
        @initial_upload_uuid = uuid_and_location[:uuid]
        @initial_upload_location = uuid_and_location[:location]
        determine_zip
      end

      def process!
        # Generates or makes calls to get, all PDFs, adds all to self.docs obj
        gather_docs!
        # Iterate over self.docs obj and add required metadata to objs directly
        docs.each { |doc| doc[:metadata] = get_meta_data(doc[:type]) }
        # Take assemebled self.docs and aggregate and send how needed
        send_to_central_mail_through_lighthouse_claims_intake_api!
      end

      private

      # Transforms the lighthouse response to the only info we actually need from it
      def upload_location_to_location_and_uuid(upload_return)
        {
          uuid: upload_return.dig('data', 'id'),
          location: upload_return.dig('data', 'attributes', 'location')
        }
      end

      # Instantiates a new location and uuid via lighthouse
      def get_upload_info
        lighthouse_service.get_upload_location.body
      end

      # Combines instantiating a new location/uuid and returning the important bits
      def get_upload_location_and_uuid
        upload_info = get_upload_info
        upload_location_to_location_and_uuid(upload_info)
      end

      def received_date
        date = SavedClaim::DisabilityCompensation.find(submission.saved_claim_id).created_at
        date = date.in_time_zone('Central Time (US & Canada)')
        date.strftime('%Y-%m-%d %H:%M:%S')
      end

      # Generate metadata for metadata.json file for the lighthouse benefits intake API to send along to Central Mail
      def get_meta_data(doc_type)
        auth_info = submission.auth_headers
        {
          "veteranFirstName": auth_info['va_eauth_firstName'], "veteranLastName": auth_info['va_eauth_lastName'],
          "fileNumber": auth_info['va_eauth_pnid'], "zipCode": zip, "source": 'va.gov backup submission',
          "docType": doc_type, "businessLine": 'CMP'
        }
      end

      def send_to_central_mail_through_lighthouse_claims_intake_api!
        is_526_or_evidence = docs.group_by do |doc|
          doc[:type] == FORM_526_DOC_TYPE || doc[:type] == FORM_526_UPLOADS_DOC_TYPE
        end
        initial_payload = is_526_or_evidence[true]
        other_payloads  = is_526_or_evidence[false]
        if SUB_METHOD == :single
          submit_as_one(initial_payload, other_payloads)
        else
          submit_initial_payload(initial_payload)
          submit_ancillary_payloads(other_payloads)
        end
      end

      def log_info(message:, upload_type:, uuid:)
        ::Rails.logger.info({ message: message, upload_type: upload_type, upload_uuid: uuid,
                              submission_id: @submission.id })
      end

      def log_resp(message:, resp:)
        ::Rails.logger.info({ message: message, response: resp, submission_id: @submission.id })
      end

      def generate_attachments(evidence_files, other_payloads)
        evidence_files.concat(other_payloads.map do |op|
                                { file: op[:file], file_name: "#{op[:metadata][:docType]}.pdf" }
                              end)
      end

      def submit_as_one(initial_payload, other_payloads = nil)
        seperated = initial_payload.group_by { |doc| doc[:type] }
        form526_doc = seperated[FORM_526_DOC_TYPE].first
        evidence_files = []
        unless seperated[FORM_526_UPLOADS_DOC_TYPE].nil?
          evidence_files = seperated[FORM_526_UPLOADS_DOC_TYPE].map.with_index do |doc, i|
            { file: doc[:file], file_name: "evidence_#{i + 1}.pdf" }
          end
        end
        attachments = other_payloads.nil? ? [] : generate_attachments(evidence_files, other_payloads)
        log_info(message: 'Uploading single fallback payload to Lighthouse', upload_type: FORM_526_DOC_TYPE,
                 uuid: initial_upload_uuid)
        lighthouse_service.upload_doc(
          upload_url: initial_upload_location,
          file: form526_doc[:file],
          metadata: form526_doc[:metadata].to_json,
          attachments: attachments
        )
        log_info(message: 'Uploading single fallback payload to Lighthouse Successful', upload_type: FORM_526_DOC_TYPE,
                 uuid: initial_upload_uuid)
        @submission.update!(backup_submitted_claim_id: initial_upload_uuid)
      end

      def submit_initial_payload(initial_payload)
        seperated = initial_payload.group_by { |doc| doc[:type] }
        form526_doc = seperated[FORM_526_DOC_TYPE].first
        evidence_files = seperated[FORM_526_UPLOADS_DOC_TYPE].map { |doc| doc[:file] }
        log_info(message: 'Uploading initial fallback payload to Lighthouse', upload_type: FORM_526_DOC_TYPE,
                 uuid: initial_upload_uuid)
        lighthouse_service.upload_doc(
          upload_url: initial_upload_location,
          file: form526_doc[:file],
          metadata: form526_doc[:metadata].to_json,
          attachments: evidence_files
        )
        log_info(message: 'Uploading initial fallback payload to Lighthouse Successful', upload_type: FORM_526_DOC_TYPE,
                 uuid: initial_upload_uuid)
        @submission.update!(backup_submitted_claim_id: initial_upload_uuid)
      end

      def submit_ancillary_payloads(docs)
        docs.each do |doc|
          ul = get_upload_location_and_uuid
          log_info(message: 'Uploading ancillary fallback payload(s) to Lighthouse', upload_type: doc[:type],
                   uuid: ul[:uuid])
          lighthouse_service.upload_doc(upload_url: ul[:location], file: doc[:file],
                                        metadata: doc[:metadata].to_json)
          log_info(message: 'Uploading ancillary fallback payload(s) to Lighthouse Successful',
                   upload_type: doc[:type], uuid: ul[:uuid])
        end
      end

      def determine_zip
        # TODO: Figure out if I need to use currentMailingAddress or changeOfAddress zip?
        # TODO: I dont think it matters too much though
        z = submission.form.dig('form526', 'form526', 'veteran', 'currentMailingAddress')
        if z.nil?
          @zip = '00000'
        else
          z_final = z['zipFirstFive']
          z_final += "-#{z['zipLastFour']}" unless z['zipLastFour'].nil?
          @zip = z_final
        end
      end

      def bdd?
        submission.form.dig('form526', 'form526', 'bddQualified') || false
      end

      def get_form526_pdf
        headers = submission.auth_headers
        form_json = JSON.parse(submission.form_json)[FORM_526].to_json
        resp = EVSS::DisabilityCompensationForm::Service.new(headers).get_form526(form_json)
        b64_enc_body = resp.body['pdf']
        content = Base64.decode64(b64_enc_body)
        file = if ::Rails.env.production?
                 content_tmpfile = Tempfile.new(TMP_FILE_PREFIX, binmode: true)
                 content_tmpfile.write(content)
                 content_tmpfile.path
               else
                 fname = "/tmp/#{Random.uuid}.pdf"
                 File.open(fname, 'wb') do |f|
                   f.write(content)
                 end
                 fname
               end
        docs << {
          type: FORM_526_DOC_TYPE,
          file: file
        }
      end

      def get_uploads
        uploads = submission.form[FORM_526_UPLOADS]
        uploads.each do |upload|
          guid = upload['confirmationCode']
          sea = SupportingEvidenceAttachment.find_by(guid: guid)
          # file_body = sea&.get_file&.read
          file = sea&.get_file
          raise ArgumentError, "supporting evidence attachment with guid #{guid} has no file data" if file.nil?

          docs << upload.merge!(file: file, type: FORM_526_UPLOADS_DOC_TYPE, evssDocType: upload['attachmentId'])
        end
      end

      def get_form4142_pdf
        processor_4142 = DecisionReviewV1::Processor::Form4142Processor.new(form_data: submission.form[FORM_4142],
                                                                            response: initial_upload)
        docs << {
          type: FORM_4142_DOC_TYPE,
          file: processor_4142.pdf_path
        }
      end

      def get_form0781_pdf
        # refactor away from EVSS eventually
        files = EVSS::DisabilityCompensationForm::SubmitForm0781.new.get_docs(submission.id, initial_upload_uuid)
        docs.concat(files)
      end

      def get_form8940_pdf
        # refactor away from EVSS eventually
        file = EVSS::DisabilityCompensationForm::SubmitForm8940.new.get_docs(submission.id)
        docs << file
      end

      def get_bdd_pdf
        # Move away from EVSS at later date
        docs << {
          type: 'bdd',
          file: 'lib/evss/disability_compensation_form/bdd_instructions.pdf'
        }
      end

      def gather_docs!
        get_form526_pdf # 21-526EZ
        get_uploads      if submission.form[FORM_526_UPLOADS]
        get_form4142_pdf if submission.form[FORM_4142]
        get_form0781_pdf if submission.form[FORM_0781]
        get_form8940_pdf if submission.form[FORM_8940]
        get_bdd_pdf      if bdd?
        # Not going to support flashes since this JOB could have already worked and be successful
        # Plus if the error is in BGS it wont work anyway
      end
    end
  end
end
