# frozen_string_literal: true
class PersistentAttachment::PensionBurial < PersistentAttachment
  UPLOADER_CLASS = ClaimDocumentation::PensionBurial::File
  include ::ClaimDocumentation::Uploader::Attachment.new(:file)

  # Business Requirement:
  # All Claims must have the time that they were received displayed in CT, which
  # is the preferred TZ for this business process. But because a claimant may live
  # in a more westerly timezone, they could submit after midnight CT while it still
  # being before midnight in their local time. If this falls on the last day of a
  # month, meaning they submitted on the first of the month CT, when their claim is
  # processed it could cause them to lose a month of benefits. To remedy that, we
  # include both the system (CT) and local (??) times.
  def stamp_text
    # set claim time to CT
    cst_submit = saved_claim.submitted_at.in_time_zone('Central Time (US & Canada)')
    # get the timezone offset of the user's submitted time (originates via js)
    user_offset = DateTime.parse(saved_claim.user_submitted_at).zone
    # nudge the system submit time (utc) by that offset to get their original local
    # time. We only trust the offset, not the full date, so the can't travel back
    # more than a day.
    local_submit = saved_claim.submitted_at.localtime(user_offset)
    "VA: #{I18n.l(cst_submit, format: :pdf_stamp)} User: #{I18n.l(local_submit, format: :pdf_stamp)}"
  end
end
