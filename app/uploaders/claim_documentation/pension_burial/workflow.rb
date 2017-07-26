# frozen_string_literal: true

require 'workflow/task/shared/convert_to_pdf'
require 'workflow/task/shared/datestamp_pdf_task'
require 'workflow/task/shared/move_to_lts'
require 'workflow/task/pension_burial/upload'

# Convert uploaded files for Pension/Burial to a format, stamping them twice
# before transfering them over to the SFTP server.

class ClaimDocumentation::PensionBurial::Workflow < Workflow::File
  run Workflow::Task::Shared::ConvertToPdf
  run Workflow::Task::Shared::DatestampPdfTask, text: 'Vets.gov', x: 0, y: 0
  run(
    Workflow::Task::Shared::DatestampPdfTask,
    text: 'FDC Reviewed - Vets.gov Submission',
    x: 429,
    y: 770,
    text_only: true
  )
  run Workflow::Task::Shared::MoveToLTS, all: true
  # run Workflow::Task::Common::DeleteOriginalUpload
  run Workflow::Task::PensionBurial::Upload
end
