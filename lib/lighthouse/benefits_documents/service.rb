# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_documents/configuration'
require 'lighthouse/service_exception'

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

    def file_number
      BGS::People::Request.new.find_person_by_participant_id(user: @user).file_number
    end

    def queue_document_upload(params, lighthouse_client_id = nil)
      loggable_params = params.except(:password)
      loggable_params[:icn] = @user.icn
      Rails.logger.info('Parameters for document upload', loggable_params)

      start_timer = Time.zone.now
      claim_id = params[:claimId] || params[:claim_id]

      unless claim_id
        raise Common::Exceptions::InternalServerError,
              ArgumentError.new("Claim with id #{claim_id} not found")
      end

      jid = submit_document(params[:file], params, lighthouse_client_id)
      StatsD.measure(STATSD_UPLOAD_LATENCY, Time.zone.now - start_timer, tags: ['is_multifile:false'])
      jid
    end

    def queue_multi_image_upload_document(params, lighthouse_client_id = nil)
      loggable_params = params.except(:password)
      loggable_params[:icn] = @user.icn
      Rails.logger.info('Parameters for document multi image upload', loggable_params)

      start_timer = Time.zone.now
      claim_id = params[:claimId] || params[:claim_id]
      unless claim_id
        raise Common::Exceptions::InternalServerError,
              ArgumentError.new("Claim with id #{claim_id} not found")
      end

      file_to_upload = generate_multi_image_pdf(params[:files])
      jid = submit_document(file_to_upload, params, lighthouse_client_id)
      StatsD.measure(STATSD_UPLOAD_LATENCY, Time.zone.now - start_timer, tags: ['is_multifile:true'])
      jid
    end

    def cleanup_after_upload
      FileUtils.rm_rf(@base_path) if @base_path
    end

    private

    def submit_document(file, file_params, lighthouse_client_id = nil)
      document_data = build_lh_doc(file, file_params)

      raise Common::Exceptions::ValidationErrors, document_data unless document_data.valid?

      uploader = LighthouseDocumentUploader.new(@user.icn, document_data.uploader_ids)
      uploader.store!(document_data.file_obj)
      # the uploader sanitizes the filename before storing, so set our doc to match
      document_data.file_name = uploader.final_filename
      Lighthouse::DocumentUpload.perform_async(@user.icn, document_data.to_serializable_hash)
    rescue CarrierWave::IntegrityError => e
      handle_error(e, lighthouse_client_id, uploader.store_dir)
    end

    def build_lh_doc(file, file_params)
      # The reason a user wouldn't have a VBMS file number is either:
      # 1. they're a rare case in production
      # 2. they're a test user in va.gov staging/LH documents_service sandbox
      file_number = file_number || @user.ssn,

      # I think rubocop is getting confused here
      # rubocop:disable Layout/ArrayAlignment
      claim_id = file_params[:claimId] || file_params[:claim_id]
      tracked_item_ids = file_params[:trackedItemIds] || file_params[:tracked_item_ids]
      document_type = file_params[:documentType] || file_params[:document_type]
      password = file_params[:password]
      # rubocop:enable Layout/ArrayAlignment

      LighthouseDocument.new(
        file_number:,
        claim_id:,
        file_obj: file,
        uuid: SecureRandom.uuid,
        file_name: file.original_filename,
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
  end
end
