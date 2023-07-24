# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_documents/configuration'
require 'lighthouse/service_exception'

module BenefitsDocuments
  class Service < Common::Client::Base
    configuration BenefitsDocuments::Configuration
    STATSD_KEY_PREFIX = 'api.benefits_documents'
    STATSD_UPLOAD_LATENCY = 'lighthouse.api.benefits.documents.latency'

    def initialize(icn)
      @icn = icn
      raise ArgumentError, 'no ICN passed in for LH API request.' if icn.blank?

      super()
    end

    def queue_document_upload(params, lighthouse_client_id = nil)
      Rails.logger.info('Parameters for document upload', params)

      start_timer = Time.zone.now
      claim_id = params[:claimId] || params[:claim_id]
      tracked_item_ids = params[:trackedItemIds] || params[:tracked_item_ids]
      document_type = params[:documentType] || params[:document_type]

      unless claim_id
        raise Common::Exceptions::InternalServerError,
              ArgumentError.new("Claim with id #{claim_id} not found")
      end

      jid = submit_document(params[:file], claim_id, tracked_item_ids, document_type, params[:password],
                            lighthouse_client_id)
      StatsD.measure(STATSD_UPLOAD_LATENCY, Time.zone.now - start_timer, tags: ['is_multifile:false'])
      jid
    end

    def queue_multi_image_upload_document(params, lighthouse_client_id = nil)
      Rails.logger.info('Parameters for document multi image upload', params)

      start_timer = Time.zone.now
      claim_id = params[:claimId] || params[:claim_id]
      tracked_item_ids = params[:trackedItemIds] || params[:tracked_item_ids]
      document_type = params[:documentType] || params[:document_type]
      unless claim_id
        raise Common::Exceptions::InternalServerError,
              ArgumentError.new("Claim with id #{claim_id} not found")
      end

      file_to_upload = generate_multi_image_pdf(params[:files])
      jid = submit_document(file_to_upload, claim_id, tracked_item_ids, document_type,
                            params[:password], lighthouse_client_id)
      StatsD.measure(STATSD_UPLOAD_LATENCY, Time.zone.now - start_timer, tags: ['is_multifile:true'])
      jid
    end

    def cleanup_after_upload
      FileUtils.rm_rf(@base_path) if @base_path
    end

    private

    # rubocop:disable Metrics/ParameterLists
    def submit_document(file, claim_id, tracked_item_id, document_type, password, lighthouse_client_id = nil)
      document_data = LighthouseDocument.new(claim_id:, file_obj: file, uuid: SecureRandom.uuid,
                                             file_name: file.original_filename, tracked_item_id:,
                                             document_type:, password:)
      raise Common::Exceptions::ValidationErrors, document_data unless document_data.valid?

      uploader = LighthouseDocumentUploader.new(@icn, document_data.uploader_ids)
      uploader.store!(document_data.file_obj)
      # the uploader sanitizes the filename before storing, so set our doc to match
      document_data.file_name = uploader.final_filename
      Lighthouse::DocumentUpload.perform_async(@icn, document_data.to_serializable_hash)
    rescue CarrierWave::IntegrityError => e
      handle_error(e, lighthouse_client_id, uploader.store_dir)
    end
    # rubocop:enable Metrics/ParameterLists

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
