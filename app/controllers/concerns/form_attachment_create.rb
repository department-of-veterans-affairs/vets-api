# frozen_string_literal: true

module FormAttachmentCreate
  extend ActiveSupport::Concern

  def create
    validate_file_upload_class!
    save_attachment_to_cloud!
    save_attachment_to_db!

    render(json: form_attachment)
  end

  private

  def validate_file_upload_class!
    # is it either ActionDispatch::Http::UploadedFile or Rack::Test::UploadedFile
    unless filtered_params[:file_data].class.name.include? 'UploadedFile'
      raise Common::Exceptions::InvalidFieldValue.new('file_data', filtered_params[:file_data].class.name)
    end
  end

  def save_attachment_to_cloud!
    form_attachment.set_file_data!(filtered_params[:file_data], filtered_params[:password])
  end

  def save_attachment_to_db!
    form_attachment.save!
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
