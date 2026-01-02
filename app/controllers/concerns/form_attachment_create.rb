# frozen_string_literal: true

module FormAttachmentCreate
  extend ActiveSupport::Concern

  def create
    debug_timestamp = Time.current.iso8601
    Rails.logger.info('begin form attachment creation',
                      {
                        file_data_present: filtered_params[:file_data].present?,
                        klass: filtered_params[:file_data]&.class&.name,
                        debug_timestamp:
                      })

    validate_file_upload_class!
    ActiveRecord::Base.transaction do
      # Save to get an ID
      save_attachment_to_db!

      # Upload using the ID
      save_attachment_to_cloud!

      # Save the file_data JSON that was set by set_file_data!
      form_attachment.save!
    end

    serialized = serializer_klass.new(form_attachment)

    Rails.logger.info('finish form attachment creation',
                      { serialized: serialized.present?,
                        debug_timestamp: })

    render json: serialized
  end

  private

  def serializer_klass
    raise NotImplementedError, 'Class must implement serializer method'
  end

  def validate_file_upload_class!
    # is it either ActionDispatch::Http::UploadedFile or Rack::Test::UploadedFile
    unless filtered_params[:file_data].class.name.include? 'UploadedFile'
      raise Common::Exceptions::InvalidFieldValue.new('file_data', filtered_params[:file_data].class.name)
    end
  rescue => e
    Rails.logger.info('form attachment error 1 - validate class',
                      { phase: 'FAC_validate',
                        klass: filtered_params[:file_data].class.name,
                        exception: e.message })
    raise e
  end

  def save_attachment_to_cloud!
    form_attachment.set_file_data!(filtered_params[:file_data], filtered_params[:password])
  rescue => e
    Rails.logger.info('form attachment error 2 - save to cloud',
                      { has_pass: filtered_params[:password].present?,
                        ext: File.extname(filtered_params[:file_data]).last(5),
                        phase: 'FAC_cloud',
                        exception: e.message })
    raise e
  end

  def save_attachment_to_db!
    form_attachment.save!
  rescue => e
    Rails.logger.info('form attachment error 3 - save to db',
                      { phase: 'FAC_db',
                        errors: form_attachment.errors,
                        exception: e.message })

    raise e
  end

  def form_attachment
    @form_attachment ||= form_attachment_model.new
  end

  def form_attachment_model
    @form_attachment_model ||= self.class::FORM_ATTACHMENT_MODEL
  end

  def filtered_params
    @filtered_params ||= extract_params_from_namespace
  end

  def extract_params_from_namespace
    namespace = form_attachment_model.to_s.underscore.split('/').last
    params.require(namespace).permit(:file_data, :password)
  end
end
