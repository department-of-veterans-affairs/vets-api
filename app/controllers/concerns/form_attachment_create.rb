# frozen_string_literal: true

module FormAttachmentCreate
  extend ActiveSupport::Concern
  include SentryLogging

  def create
    debug_timestamp = Time.current.iso8601
    if Flipper.enabled?(:hca_log_form_attachment_create)
      log_message_to_sentry(
        'begin form attachment creation',
        :info,
        file_data_present: filtered_params[:file_data].present?,
        class_name: filtered_params[:file_data]&.class&.name,
        debug_timestamp:
      )
    end

    validate_file_upload_class!
    save_attachment_to_cloud!
    save_attachment_to_db!

    serialized = serializer_klass.new(form_attachment)

    if Flipper.enabled?(:hca_log_form_attachment_create)
      log_message_to_sentry('finish form attachment creation', :info, serialized: serialized.present?, debug_timestamp:)
    end

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
    log_exception_to_sentry(e, { context: 'FAC_validate', class: filtered_params[:file_data].class.name })
    raise e
  end

  def save_attachment_to_cloud!
    form_attachment.set_file_data!(filtered_params[:file_data], filtered_params[:password])
  rescue => e
    log_exception_to_sentry(e, { context: 'FAC_cloud' })
    raise e
  end

  def save_attachment_to_db!
    form_attachment.save!
  rescue => e
    log_exception_to_sentry(e, { context: 'FAC_db', errors: form_attachment.errors })
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
