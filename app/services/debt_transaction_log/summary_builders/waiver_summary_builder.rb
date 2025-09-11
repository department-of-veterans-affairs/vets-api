# frozen_string_literal: true

class DebtTransactionLog::SummaryBuilders::WaiverSummaryBuilder
  def self.build(submission)
    {
      debt_type: submission.public_metadata&.dig('debt_type') || 'unknown',
      combined: submission.public_metadata&.dig('combined') == true,
      streamlined: submission.public_metadata&.dig('streamlined', 'value') == true
    }
  end
end
