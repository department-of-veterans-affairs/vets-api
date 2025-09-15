# frozen_string_literal: true

class DebtTransactionLog::SummaryBuilders::DisputeSummaryBuilder
  def self.build(submission)
    file_count = submission.respond_to?(:files) && submission.files&.attached? ? submission.files.count : 0

    {
      debt_types: submission.public_metadata&.dig('debt_types') || [],
      dispute_reasons: submission.public_metadata&.dig('dispute_reasons') || [],
      file_count:
    }
  end
end
