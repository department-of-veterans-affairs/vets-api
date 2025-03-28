# frozen_string_literal: true

module BenefitsDocuments
  module Constants
    UPLOAD_STATUS = {
      CREATED: 'CREATED',
      QUEUED: 'QUEUED',
      PENDING: 'IN_PROGRESS',
      FAILED: 'FAILED',
      SUCCESS: 'SUCCESS'
    }.freeze

    VANOTIFY_STATUS = {
      FAILED: 'FAILED',
      SUCCESS: 'SUCCESS'
    }.freeze
  end
end
