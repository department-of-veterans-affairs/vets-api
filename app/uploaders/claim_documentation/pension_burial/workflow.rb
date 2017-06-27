# frozen_string_literal: true
class ClaimDocumentation::PensionBurial::Workflow < Workflow::File
  run Workflow::Task::Shared::DatestampPdfTask, text: 'Vets.gov', x: 0, y: 0
  run Workflow::Task::Shared::MoveToLTS, all: true
  # run Workflow::Task::Common::DeleteOriginalUpload
  run Workflow::Task::PensionBurial::Upload
end
