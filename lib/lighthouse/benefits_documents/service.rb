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

    def initialize(user)
      @user = user
      raise ArgumentError, 'no user passed in for LH API request.' if @user.blank?

      super()
    end

    def queue_document_upload(params, lighthouse_client_id = nil)
      loggable_params = params.except(:password)
      Rails.logger.info('Parameters for document upload', loggable_params)

      start_timer = Time.zone.now

      jid = submit_document(params[:file], params, lighthouse_client_id)
      StatsD.measure(STATSD_UPLOAD_LATENCY, Time.zone.now - start_timer, tags: ['is_multifile:false'])
      jid
    end

    def queue_multi_image_upload_document(params, lighthouse_client_id = nil)
      loggable_params = params.except(:password)
      loggable_params[:icn] = @user.icn
      Rails.logger.info('Parameters for document multi image upload', loggable_params)

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

    private

    def submit_document(file, file_params, lighthouse_client_id = nil) # rubocop:disable Metrics/MethodLength
      user_icn = @user.icn
      document_data = build_lh_doc(file, file_params)
      claim_id = file_params[:claimId] || file_params[:claim_id]

      unless claim_id
        raise Common::Exceptions::InternalServerError,
              ArgumentError.new('Claim id is required')
      end

      Rails.logger.info('file_name present?', file&.original_filename.present?)
      Rails.logger.info('file extension', file&.original_filename&.split('.')&.last)
      Rails.logger.info('file content type', file&.content_type)
      Rails.logger.info('participant_id present?', @user.participant_id.present?)

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
  end
end
