# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'evss/disability_compensation_auth_headers'
require 'evss/disability_compensation_form/form4142'
require 'evss/disability_compensation_form/service'
require 'evss/disability_compensation_form/non_breakered_service'
require 'form526_backup_submission/service'
require 'decision_review_v1/utilities/form_4142_processor'
require 'pdf_utilities/datestamp_pdf'
require 'pdf_fill/filler'
require 'logging/third_party_transaction'
require 'simple_forms_api_submission/metadata_validator'
require 'disability_compensation/factories/api_provider_factory'
require 'common/s3_helpers'

module Sidekiq
  module Form526BackupSubmissionProcess
    class Processor
      extend Logging::ThirdPartyTransaction::MethodWrapper

      attr_reader :submission, :lighthouse_service, :zip, :initial_upload_location, :initial_upload_uuid,
                  :initial_upload, :docs_gathered, :initial_upload_fetched, :ignore_expiration,
                  :submission_id
      attr_accessor :docs

      wrap_with_logging(
        :get_form_from_external_api,
        :instantiate_upload_info_from_lighthouse,
        :get_from_non_breakered_service,
        additional_instance_logs: [
          submission_id: %i[submission_id],
          initial_upload_uuid: %i[initial_upload_uuid],
          initial_upload_location: %i[initial_upload_location]
        ]
      )

      FORM_526 = 'form526'
      FORM_526_DOC_TYPE = '21-526EZ'
      FORM_526_UPLOADS = 'form526_uploads'
      FORM_526_UPLOADS_DOC_TYPE = 'evidence'
      FORM_4142 = 'form4142'
      FORM_4142_DOC_TYPE = '21-4142'
      FORM_0781 = 'form0781'
      FORM_8940 = 'form8940'
      FLASHES = 'flashes'
      BKUP_SETTINGS = Settings.key?(:form526_backup) ? Settings.form526_backup : OpenStruct.new
      DOCTYPE_MAPPING = {
        '21-526EZ' => 'L533',
        '21-4142' => 'L107',
        '21-0781' => 'L228',
        '21-0781a' => 'L229',
        '21-0781V2' => 'L228',
        '21-8940' => 'L149',
        'bdd' => 'L023'
      }.freeze
      DOCTYPE_NAMES = %w[
        21-526EZ
        21-4142
        21-0781
        21-0781a
        21-0781V2
        21-8940
      ].freeze
      MAX_FILENAME_LENGTH = 100

      SUB_METHOD = (BKUP_SETTINGS.submission_method || 'single').to_sym

      # Takes a submission id, assembles all needed docs from its payload, then sends it to central mail via
      # lighthouse benefits intake API - https://developer.va.gov/explore/benefits/docs/benefits?version=current
      def initialize(submission_id, docs = [], get_upload_location_on_instantiation: true, ignore_expiration: false)
        @submission_id = submission_id
        @submission = Form526Submission.find(submission_id)
        @user_account = @submission.account
        @docs = docs
        @docs_gathered = false
        @initial_upload_fetched = false
        @lighthouse_service = Form526BackupSubmission::Service.new
        @ignore_expiration = ignore_expiration
        # We need an initial location/uuid as other ancillary docs want a reference id to it
        # (eventhough I dont think they actually use it for anything because we are just using them to
        # generate the pdf and not the sending portion of those classes... but it needs something there to not error)
        instantiate_upload_info_from_lighthouse if get_upload_location_on_instantiation

        determine_zip
      end

      def process!
        # Generates or makes calls to get, all PDFs, adds all to self.docs obj
        gather_docs! unless @docs_gathered
        # Take assemebled self.docs and aggregate and send how needed
        send_to_central_mail_through_lighthouse_claims_intake_api!
      end

      def gather_docs!
        get_form526_pdf # 21-526EZ
        get_uploads      if submission.form[FORM_526_UPLOADS]
        get_form4142_pdf if submission.form[FORM_4142]
        get_form0781_pdf if submission.form[FORM_0781]
        get_form8940_pdf if submission.form[FORM_8940]
        get_bdd_pdf      if bdd?
        convert_docs_to_pdf
        # Iterate over self.docs obj and add required metadata to objs directly
        docs.each { |doc| doc[:metadata] = get_meta_data(doc[:type]) }
        @docs_gathered = true
      end

      # [remediation effort] This code is to take a 526 submission, generate the pdfs,
      # and upload to aws for manual review
      def upload_pdf_submission_to_s3(return_url: false, url_life_length: 1.week.to_i)
        gather_docs! unless @docs_gathered
        i = 0
        params_docs = docs.map do |doc|
          doc_type = doc[:evssDocType] || doc[:metadata][:docType]
          {
            file_path: BenefitsIntakeService::Service.get_file_path_from_objs(doc[:file]),
            docType: DOCTYPE_MAPPING[doc_type] || doc_type,
            file_name: DOCTYPE_NAMES.include?(doc_type) ? "#{doc_type}.pdf" : "attachment#{i += 1}.pdf"
          }
        end
        metadata = get_meta_data(FORM_526_DOC_TYPE)
        zipname = "#{submission.id}.zip"
        generate_zip_and_upload(params_docs, zipname, metadata,
                                return_url, url_life_length)
      end

      def instantiate_upload_info_from_lighthouse
        initial_upload = @lighthouse_service.get_location_and_uuid
        @initial_upload_uuid = initial_upload[:uuid]
        @initial_upload_location = initial_upload[:location]
        @initial_upload_fetched = true
      end

      def evidence_526_split
        is_526_or_evidence = docs.group_by do |doc|
          [FORM_526_DOC_TYPE, FORM_526_UPLOADS_DOC_TYPE].include?(doc[:type])
        end
        [is_526_or_evidence[true], is_526_or_evidence[false]]
      end

      def generate_zip_and_upload(params_docs, zipname, metadata, return_url, url_life_length) # rubocop:disable Metrics/MethodLength
        zip_path_and_name = "tmp/#{zipname}"
        Zip::File.open(zip_path_and_name, create: true) do |zipfile|
          zipfile.get_output_stream('metadata.json') { |f| f.puts metadata.to_json }
          zipfile.get_output_stream('mappings.json') do |f|
            f.puts params_docs.to_h { |q|
                     [q[:file_name], q[:docType]]
                   }.to_json
          end
          params_docs.each { |doc| zipfile.add(doc[:file_name], doc[:file_path]) }
        end

        s3_resource = new_s3_resource

        obj = Common::S3Helpers.upload_file(
          s3_resource:,
          bucket: s3_bucket,
          key: zipname,
          file_path: zip_path_and_name,
          content_type: 'application/zip',
          return_object: true
        )
        obj_ret = true

        if return_url
          obj.presigned_url(:get, expires_in: url_life_length)
        else
          obj_ret
        end
      ensure
        Common::FileHelpers.delete_file_if_exists(zip_path_and_name)
      end

      # [remediation effort]
      def s3_bucket
        Settings.form526_backup.aws.bucket
      end

      # [remediation effort]
      def new_s3_resource
        Aws::S3::Resource.new(
          region: Settings.form526_backup.aws.region,
          access_key_id: Settings.form526_backup.aws.access_key_id,
          secret_access_key: Settings.form526_backup.aws.secret_access_key
        )
      end

      # Transforms the lighthouse response to the only info we actually need from it
      def upload_location_to_location_and_uuid(upload_return)
        {
          uuid: upload_return.dig('data', 'id'),
          location: upload_return.dig('data', 'attributes', 'location')
        }
      end

      def received_date
        date = SavedClaim::DisabilityCompensation.find(submission.saved_claim_id).created_at
        date = date.in_time_zone('Central Time (US & Canada)')
        date.strftime('%Y-%m-%d %H:%M:%S')
      end

      # Generate metadata for metadata.json file for the lighthouse benefits intake API to send along to Central Mail
      def get_meta_data(doc_type)
        auth_info = submission.auth_headers
        metadata = {
          'veteranFirstName' => auth_info['va_eauth_firstName'],
          'veteranLastName' => auth_info['va_eauth_lastName'],
          'fileNumber' => auth_info['va_eauth_pnid'],
          'zipCode' => zip,
          'source' => 'va.gov backup submission',
          'docType' => doc_type,
          'businessLine' => 'CMP',
          'claimDate' => submission.created_at.iso8601,
          'forceOfframp' => 'true'
        }
        SimpleFormsApiSubmission::MetadataValidator.validate(metadata)
      end

      def send_to_central_mail_through_lighthouse_claims_intake_api!
        instantiate_upload_info_from_lighthouse unless @initial_upload_fetched
        initial_payload, other_payloads = evidence_526_split
        if SUB_METHOD == :single
          submit_as_one(initial_payload, other_payloads)
        else
          submit_initial_payload(initial_payload)
          submit_ancillary_payloads(other_payloads)
        end
      end

      def log_info(message:, upload_type:, uuid:)
        ::Rails.logger.info({ message:, upload_type:, upload_uuid: uuid,
                              submission_id: @submission.id })
      end

      def log_resp(message:, resp:)
        ::Rails.logger.info({ message:, response: resp, submission_id: @submission.id })
      end

      def generate_attachments(evidence_files, other_payloads)
        return evidence_files if other_payloads.nil?

        other_payloads.each do |op|
          evidence_files << { file: op[:file], file_name: "#{op[:metadata][:docType]}.pdf" }
        end
        evidence_files
      end

      def submit_to_lh_claims_intake_api(form526_doc, attachments)
        log_info(message: 'Uploading single fallback payload to Lighthouse', upload_type: FORM_526_DOC_TYPE,
                 uuid: initial_upload_uuid)
        lighthouse_service.upload_doc(
          upload_url: initial_upload_location,
          file: form526_doc[:file],
          metadata: form526_doc[:metadata].to_json,
          attachments:
        )
        log_info(message: 'Uploading single fallback payload to Lighthouse Successful', upload_type: FORM_526_DOC_TYPE,
                 uuid: initial_upload_uuid)
        @submission.update!(backup_submitted_claim_id: initial_upload_uuid)
      end

      def return_upload_params_and_docs(form526_doc, attachments)
        lighthouse_service.get_upload_docs(
          file_with_full_path: form526_doc[:file],
          metadata: form526_doc[:metadata].to_json,
          attachments:
        )
      end

      def submit_as_one(initial_payload, other_payloads = nil, return_docs_instead_of_sending: false)
        seperated = initial_payload.group_by { |doc| doc[:type] }
        form526_doc = seperated[FORM_526_DOC_TYPE].first
        evidence_files = []
        unless seperated[FORM_526_UPLOADS_DOC_TYPE].nil?
          evidence_files = seperated[FORM_526_UPLOADS_DOC_TYPE].map.with_index do |doc, i|
            { file: doc[:file], file_name: "evidence_#{i + 1}.pdf" }
          end
        end
        attachments = generate_attachments(evidence_files, other_payloads)
        # Optional exit point to just return the docs/payloads, to be utilized by other classes
        if return_docs_instead_of_sending
          return_upload_params_and_docs(form526_doc, attachments)
        else
          submit_to_lh_claims_intake_api(form526_doc, attachments)
        end
      end

      def submit_initial_payload(initial_payload)
        seperated = initial_payload.group_by { |doc| doc[:type] }
        form526_doc = seperated[FORM_526_DOC_TYPE].first
        evidence_files = seperated[FORM_526_UPLOADS_DOC_TYPE].pluck(:file)
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
        z = submission.form.dig('form526', 'form526', 'veteran', 'currentMailingAddress')
        if z.nil? || z['country']&.downcase != 'usa'
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

      def write_to_tmp_file(content, ext = 'pdf')
        fname = "#{Common::FileHelpers.random_file_path}.#{ext}"
        File.binwrite(fname, content)
        fname
      end

      def get_form526_pdf
        headers = submission.auth_headers
        submission_create_date = submission.created_at.strftime('%Y-%m-%d')
        form_json = submission.form[FORM_526]
        form_json[FORM_526]['claimDate'] ||= submission_create_date
        form_json[FORM_526]['applicationExpirationDate'] = 365.days.from_now.iso8601 if @ignore_expiration

        transaction_id = submission.system_transaction_id
        resp = get_form_from_external_api(headers, ApiProviderFactory::API_PROVIDER[:lighthouse], form_json.to_json,
                                          transaction_id)
        content = resp.env.response_body

        file = write_to_tmp_file(content)
        docs << { type: FORM_526_DOC_TYPE, file: }
      end

      # 82245 - Adding provider to method. this should be removed when toxic exposure flipper is removed
      # @param headers auth headers for evss transmission
      # @param provider which provider is desired? :evss or :lighthouse
      # @param form_json the request body as a hash
      # @param transaction_id for lighthouse provider only: to track submission's journey in APM(s) across systems
      def get_form_from_external_api(headers, provider, form_json, transaction_id = nil)
        # get the "breakered" version
        service = choose_provider(headers, provider, breakered: true)
        service.generate_526_pdf(form_json, transaction_id)
      end

      def get_uploads
        uploads = submission.form[FORM_526_UPLOADS]
        uploads.each do |upload|
          guid = upload['confirmationCode']
          sea = SupportingEvidenceAttachment.find_by(guid:)
          file = sea&.get_file
          raise ArgumentError, "supporting evidence attachment with guid #{guid} has no file data" if file.nil?

          filename = File.basename(file.path, '.*')[0..MAX_FILENAME_LENGTH]
          file_extension = File.extname(file.path)
          entropied_fname = "#{Common::FileHelpers.random_file_path}.#{Time.now.to_i}.#{filename}#{file_extension}"
          File.binwrite(entropied_fname, file.read)
          docs << upload.merge!(file: entropied_fname, type: FORM_526_UPLOADS_DOC_TYPE,
                                evssDocType: upload['attachmentId'])
        end
      end

      def get_form4142_pdf
        processor4142 = EVSS::DisabilityCompensationForm::Form4142Processor.new(submission, submission_id)
        docs << {
          type: FORM_4142_DOC_TYPE,
          file: processor4142.pdf_path
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

      def convert_docs_to_pdf
        ::Rails.logger.info(
          'Begin 526 PDF Generating for Backup Submission',
          { submission_id:, initial_upload_uuid: }
        )

        klass = BenefitsIntakeService::Utilities::ConvertToPdf
        result = docs.each do |doc|
          convert_doc_to_pdf(doc, klass)
        end

        ::Rails.logger.info(
          'Complete 526 PDF Generating for Backup Submission',
          { submission_id:, initial_upload_uuid: }
        )
        result
      end

      def convert_doc_to_pdf(doc, klass)
        actual_path_to_file = @lighthouse_service.get_file_path_from_objs(doc[:file])
        file_type_extension = File.extname(actual_path_to_file).downcase
        if klass::CAN_CONVERT.include?(file_type_extension)
          ::Rails.logger.info(
            'Generating PDF document',
            { actual_path_to_file:, file_type_extension: }
          )

          doc[:file] = klass.new(actual_path_to_file).converted_filename
          # delete old pulled down file after converted (in prod, dont delete spec/test files),
          # dont care about it anymore, the converted file gets deleted later after successful submission
          Common::FileHelpers.delete_file_if_exists(actual_path_to_file) if ::Rails.env.production?
        end
      end

      # 82245 - Adding provider to method. this should be removed when toxic exposure flipper is removed
      def choose_provider(headers, _provider, breakered: true)
        ApiProviderFactory.call(
          type: ApiProviderFactory::FACTORIES[:generate_pdf],
          provider: :lighthouse,
          # this sends the auth headers and if we want the "breakered" or "non-breakered" version
          options: { auth_headers: headers, breakered: },
          current_user: OpenStruct.new({ flipper_id: submission.user_uuid, icn: @user_account.icn }),
          feature_toggle: nil
        )
      end
    end

    class NonBreakeredProcessor < Processor
      def get_form526_pdf
        headers = submission.auth_headers
        submission_create_date = submission.created_at.iso8601
        form_json = submission.form[FORM_526]
        form_json[FORM_526]['claimDate'] ||= submission_create_date
        form_json[FORM_526]['applicationExpirationDate'] = 365.days.from_now.iso8601 if @ignore_expiration

        form_version = submission.saved_claim.parsed_form['startedFormVersion']
        if form_version.present?
          resp = get_from_non_breakered_service(headers, ApiProviderFactory::API_PROVIDER[:lighthouse],
                                                form_json.to_json)
          content = resp.env.response_body
        else
          resp = get_from_non_breakered_service(headers, ApiProviderFactory::API_PROVIDER[:evss], form_json.to_json)
          b64_enc_body = resp.body['pdf']
          content = Base64.decode64(b64_enc_body)
        end
        file = write_to_tmp_file(content)
        docs << {
          type: FORM_526_DOC_TYPE,
          file:
        }
      end
    end

    # 82245 - Adding provider to method. this should be removed when toxic exposure flipper is removed
    def get_from_non_breakered_service(headers, provider, form_json)
      # get the "non-breakered" version
      service = choose_provider(headers, provider, breakered: false)

      service.get_form526(form_json)
    end

    class NonBreakeredForm526BackgroundLoader
      extend ActiveSupport::Concern
      include Sidekiq::Job
      sidekiq_options retry: false
      def perform(id)
        NonBreakeredProcessor.new(id, get_upload_location_on_instantiation: false,
                                      ignore_expiration: true).upload_pdf_submission_to_s3
      end
    end
  end
end
