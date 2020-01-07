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

    file_data = params.require(namespace).permit(:file_data)

    form_attachment.set_file_data!(file_data)
    form_attachment.save!
    render(json: form_attachment)
  end
end
