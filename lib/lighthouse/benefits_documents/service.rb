# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_documents/configuration'
require 'lighthouse/service_exception'
require 'lighthouse/benefits_documents/constants'
require 'lighthouse/benefits_documents/utilities/helpers'

module BenefitsDocuments
  class Service < Common::Client::Base
    configuration BenefitsDocuments::Configuration

    STATSD_KEY_PREFIX = 'api.benefits_documents'
    STATSD_UPLOAD_LATENCY = 'lighthouse.api.benefits.documents.latency'

    # In order to avoid logging sensitive data, we need to exclude these params from the logs
    DISALLOWED_PARAMS = %i[qqfilename password].freeze

    def initialize(user)
      @user = user
      raise ArgumentError, 'no user passed in for LH API request.' if @user.blank?

      super()
    end

    def queue_document_upload(params, lighthouse_client_id = nil)
      Rails.logger.info('Parameters for document upload', filter_sensitive_params(params))

      start_timer = Time.zone.now

      jid = submit_document(params[:file], params, lighthouse_client_id)
      StatsD.measure(STATSD_UPLOAD_LATENCY, Time.zone.now - start_timer, tags: ['is_multifile:false'])
      jid
    end

    def queue_multi_image_upload_document(params, lighthouse_client_id = nil)
      Rails.logger.info(
        'Parameters for document multi image upload',
        filter_sensitive_params(params, multi_file: true)
      )

      start_timer = Time.zone.now

      file_to_upload = generate_multi_image_pdf(params[:files])
      jid = submit_document(file_to_upload, params, lighthouse_client_id)
      StatsD.measure(STATSD_UPLOAD_LATENCY, Time.zone.now - start_timer, tags: ['is_multifile:true'])
      jid
    end

    def cleanup_after_upload
      FileUtils.rm_rf(@base_path) if @base_path
    end

    # gets all claim letters from the lighthouse claims-letters/search endpoint
    def claim_letters_search(doc_type_ids: nil, participant_id: nil, file_number: nil)
      config.claim_letters_search(doc_type_ids:, participant_id:, file_number:)
    rescue Faraday::ClientError, Faraday::ServerError => e
      handle_error(e, nil, 'services/benefits-documents/v1/claim-letters/search')
    end

    # retrieves the octet-stream of a single claim letter from the lighthouse claims-letters/download endpoint
    def claim_letter_download(document_uuid:, participant_id: nil, file_number: nil)
      config.claim_letter_download(document_uuid:, participant_id:, file_number:)
    rescue Faraday::ClientError, Faraday::ServerError => e
      handle_error(e, nil, 'services/benefits-documents/v1/claim-letters/download')
    end

    def validate_claimant_can_upload(document_data)
      response = config.claimant_can_upload_document(document_data)
      response.body.dig('data', 'valid') # boolean
    rescue Faraday::ClientError, Faraday::ServerError => e
      handle_error(e, nil, 'services/benefits-documents/v1/documents/validate/claimant')
      false
    end

    # Returns a list of all VBMS document names related to participantId.
    # @param participant_id: integer A unique identifier assigned to each patient entry
    # in the Master Patient Index linking patients to their records across VA systems.
    # Example: 999012105
    # @param page_number: integer 1-based page number to retrieve. Defaults to 1.
    # Example: 1
    # @param page_size: integer Number of results per page (1–100). Defaults to 100. Maximum 100.
    # Example: 100
    def participant_documents_search(participant_id:, page_number: 1, page_size: 100)
      config.participant_documents_search(participant_id:, page_number:, page_size:)
    rescue Faraday::ClientError, Faraday::ServerError => e
      handle_error(e, nil, 'services/benefits-documents/v1/participant/documents/search')
    end

    # Download the full content of a document (such as a PDF).
    # The document must be identified by its unique ID, and associated with either a Participant ID or File Number.
    # @param document_uuid: string The document's unique identifier in VBMS,
    # obtained by making a Document Service API request to search for documents
    # that are available to download for the Veteran.
    # Note that this differs from the document's current version UUID.
    # @param participant_id: integer A unique identifier assigned to each patient entry
    # in the Master Patient Index linking patients to their records across VA systems.
    # Example: 999012105
    # @param file_number: string The Veteran's VBMS fileNumber used when uploading the document to VBMS.
    # It indicates the eFolder in which the document resides.
    # Example: "999012105"
    def participant_documents_download(document_uuid:, participant_id: nil, file_number: nil)
      config.participant_documents_download(document_uuid:, participant_id:, file_number:)
    rescue Faraday::ClientError, Faraday::ServerError => e
      handle_error(e, nil, 'services/benefits-documents/v1/participant/documents/download')
    end

    private

    def submit_document(file, file_params, lighthouse_client_id = nil) # rubocop:disable Metrics/MethodLength
      user_icn = @user.icn
      document_data = build_lh_doc(file, file_params)
      claim_id = file_params[:claimId] || file_params[:claim_id]

      unless claim_id
        raise Common::Exceptions::InternalServerError,
              ArgumentError.new('Claim id is required')
      end

      if presumed_duplicate?(claim_id, file)
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: 'DOC_UPLOAD_DUPLICATE',
          source: self.class.name
        )
      end

      unless validate_claimant_can_upload(document_data)
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: 'DOC_UPLOAD_INVALID_CLAIMANT',
          source: self.class.name
        )
      end

      raise Common::Exceptions::ValidationErrors, document_data unless document_data.valid?

      uploader = LighthouseDocumentUploader.new(user_icn, document_data.uploader_ids)
      uploader.store!(document_data.file_obj)

      evidence_submission_id = nil
      evidence_submission_id = create_initial_evidence_submission(document_data).id if can_create_evidence_submission

      # The uploader sanitizes the filename before storing, so set our doc to match
      document_data.file_name = uploader.final_filename
      document_upload(user_icn, document_data.to_serializable_hash, evidence_submission_id)
    rescue CarrierWave::IntegrityError => e
      handle_error(e, lighthouse_client_id, uploader.store_dir)
      raise e
    end

    def document_upload(user_icn, document_hash, evidence_submission_id)
      if Flipper.enabled?(:cst_synchronous_evidence_uploads, @user)
        Lighthouse::DocumentUploadSynchronous.upload(user_icn, document_hash)
      else
        Lighthouse::EvidenceSubmissions::DocumentUpload.perform_async(user_icn, document_hash, evidence_submission_id)
      end
    end

    def create_initial_evidence_submission(document)
      user_account = UserAccount.find(@user.user_account_uuid)
      es = EvidenceSubmission.create(
        claim_id: document.claim_id,
        tracked_item_id: document.tracked_item_id&.first,
        upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:CREATED],
        user_account:,
        file_size: File.size(document.file_obj),
        template_metadata: { personalisation: create_personalisation(document) }.to_json
      )
      StatsD.increment('cst.lighthouse.document_uploads.evidence_submission_record_created')
      ::Rails.logger.info('LH - Created Evidence Submission Record', {
                            claim_id: document.claim_id,
                            evidence_submission_id: es.id
                          })
      es
    end

    def create_personalisation(document)
      { first_name: document.first_name.titleize,
        document_type: document.description,
        file_name: document.file_name,
        obfuscated_file_name: BenefitsDocuments::Utilities::Helpers.generate_obscured_file_name(document.file_name),
        date_submitted: BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(Time.zone.now),
        date_failed: nil }
    end

    def build_lh_doc(file, file_params)
      claim_id = file_params[:claimId] || file_params[:claim_id]
      tracked_item_ids = file_params[:trackedItemIds] || file_params[:tracked_item_ids]
      document_type = file_params[:documentType] || file_params[:document_type]
      password = file_params[:password]

      unless document_type
        raise Common::Exceptions::InternalServerError,
              ArgumentError.new('document_type is required')
      end

      LighthouseDocument.new(
        first_name: @user.first_name,
        participant_id: @user.participant_id,
        claim_id:,
        file_obj: file,
        uuid: SecureRandom.uuid,
        file_name: file.original_filename,
        # We should pull the string out of the array for the tracked item since lighthouse gives us an array
        # NOTE there will only be one tracked item here
        # TODO Update this so that we only pass a tracked item instead of an array of tracked items
        # Created https://github.com/department-of-veterans-affairs/va.gov-team/issues/101200 for this work
        tracked_item_id: tracked_item_ids,
        document_type:,
        password:
      )
    end

    def handle_error(error, lighthouse_client_id, endpoint)
      Lighthouse::ServiceException.send_error(
        error,
        self.class.to_s.underscore,
        lighthouse_client_id,
        "#{config.base_api_path}/#{endpoint}"
      )
    end

    def generate_multi_image_pdf(image_list)
      @base_path = Rails.root.join 'tmp', 'uploads', 'cache', SecureRandom.uuid
      img_path = "#{@base_path}/tempFile.jpg"
      pdf_filename = 'multifile.pdf'
      pdf_path = "#{@base_path}/#{pdf_filename}"
      FileUtils.mkpath @base_path
      Prawn::Document.generate(pdf_path) do |pdf|
        image_list.each do |img|
          File.binwrite(img_path, Base64.decode64(img))
          img = MiniMagick::Image.open(img_path)
          if img.height > pdf.bounds.top || img.width > pdf.bounds.right
            pdf.image img_path, fit: [pdf.bounds.right, pdf.bounds.top]
          else
            pdf.image img_path
          end
          pdf.start_new_page unless pdf.page_count == image_list.length
        end
      end
      temp_file = Tempfile.new(pdf_filename, encoding: 'ASCII-8BIT')
      temp_file.write(File.read(pdf_path))
      ActionDispatch::Http::UploadedFile.new(filename: pdf_filename, type: 'application/pdf', tempfile: temp_file)
    end

    def can_create_evidence_submission
      Flipper.enabled?(:cst_send_evidence_submission_failure_emails) && !Flipper.enabled?(
        :cst_synchronous_evidence_uploads, @user
      )
    end

    def presumed_duplicate?(claim_id, file)
      user_account = UserAccount.find_by(id: @user.user_account_uuid)
      es = EvidenceSubmission.where(
        claim_id:,
        user_account:,
        upload_status: [
          BenefitsDocuments::Constants::UPLOAD_STATUS[:CREATED],
          BenefitsDocuments::Constants::UPLOAD_STATUS[:QUEUED],
          BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING]
        ]
      )
      return false unless es.exists?

      es.find_each do |submission|
        filename = JSON.parse(submission.template_metadata).dig('personalisation', 'file_name')
        if (filename == file.original_filename) &&
           (submission.file_size.nil? || submission.file_size == File.size(file))
          return true
        end
      end

      false
    end

    # To avoid logging PII, this method filters out sensitive data while keeping other pertinent data unchanged
    def filter_sensitive_params(params, multi_file: false)
      unfiltered_params = params.is_a?(Hash) ? params : params.to_unsafe_h
      allowed_params = unfiltered_params.except(*DISALLOWED_PARAMS)
      # If the 'files' key is present, it means multiple files are being uploaded
      # so we need to filter all the file data
      filtered_params =
        if multi_file
          files = allowed_params.slice(:files)
          nested_files = allowed_params[:claims_and_appeal]&.slice(:files)
          # Merge the files and nested files into a single hash
          all_file_data = files.merge(claims_and_appeal: nested_files).compact
          # Filter all file data
          ParameterFilterHelper.filter_params(all_file_data)
        else
          ParameterFilterHelper.filter_params(allowed_params.slice(:file))
        end
      # Return everything except the disallowed params plus the filtered params
      allowed_params.merge(filtered_params)
    end
  end
end
