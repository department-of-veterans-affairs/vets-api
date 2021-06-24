# frozen_string_literal: true

module FormAttachmentCreate
  extend ActiveSupport::Concern

  def create
    form_attachment_model = self.class::FORM_ATTACHMENT_MODEL
    form_attachment = form_attachment_model.new
    namespace = form_attachment_model.to_s.underscore.split('/').last
    filtered_params = params.require(namespace).permit(:file_data, :password)
    # is it either ActionDispatch::Http::UploadedFile or Rack::Test::UploadedFile
    unless filtered_params[:file_data].class.name.include? 'UploadedFile'
      raise Common::Exceptions::InvalidFieldValue.new('file_data', filtered_params[:file_data].class.name)
    end

    form_attachment.set_file_data!(filtered_params[:file_data], filtered_params[:password])
    form_attachment.save!
    render(json: form_attachment)
  end
end
