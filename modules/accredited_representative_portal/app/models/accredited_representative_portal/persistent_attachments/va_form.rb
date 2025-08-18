# frozen_string_literal: true

class AccreditedRepresentativePortal::PersistentAttachments::VAForm < PersistentAttachments::VAForm
  include ::AccreditedRepresentativePortal::Uploader::Attachment.new(:file)
end
