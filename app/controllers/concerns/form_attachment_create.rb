# frozen_string_literal: true

module FormAttachmentCreate
  extend ActiveSupport::Concern

  included do
    skip_before_action(:authenticate, raise: false)
  end

  def create
    form_attachment_model = self.class::FORM_ATTACHMENT_MODEL
    form_attachment = form_attachment_model.new
    namespace = form_attachment_model.to_s.underscore.split('/').last
    filtered_params = params.require(namespace).permit(:file_data, :password)
    form_attachment.set_file_data!(filtered_params[:file_data], filtered_params[:password])
    form_attachment.save!
    render(json: form_attachment)
  end
end
