# frozen_string_literal: true

module FormAttachmentCreate
  extend ActiveSupport::Concern

  def create # rubocop:disable Metrics/AbcSize
    form_attachment_model = self.class::FORM_ATTACHMENT_MODEL
    serializer_model      = defined?(self.class::FORM_ATTACHMENT_SERIALIZER) && self.class::FORM_ATTACHMENT_SERIALIZER

    form_attachment = form_attachment_model.new
    namespace = form_attachment_model.to_s.underscore.split('/').last
    filtered_params = params.require(namespace).permit(:file_data, :password)
    form_attachment.set_file_data!(filtered_params[:file_data], filtered_params[:password])
    form_attachment.save!

    response = { json: form_attachment }
    response.merge!(serializer: serializer_model) if serializer_model

    render response
  end
end
