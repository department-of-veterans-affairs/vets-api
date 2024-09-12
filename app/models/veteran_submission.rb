# frozen_string_literal: true

class VeteranSubmission < ApplicationRecord
  enum :status, %i[created succeeded failed_with_notification failed_silently]
end
