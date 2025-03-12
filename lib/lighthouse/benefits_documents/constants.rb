# frozen_string_literal: true

module BenefitsDocuments
  module Constants
    UPLOAD_STATUS = {
      PENDING: 'IN_PROGRESS',
      FAILED: 'FAILED',
      SUCCESS: 'SUCCESS',
      QUEUED: 'QUEUED',
      CREATED: 'CREATED'
    }.freeze

    VANOTIFY_STATUS = {
      FAILED: 'FAILED',
      SUCCESS: 'SUCCESS'
    }.freeze
  end
end
