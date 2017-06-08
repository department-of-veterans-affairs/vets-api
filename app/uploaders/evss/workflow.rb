# frozen_string_literal: true
require 'workflow/task/common/move_to_lts'
require 'workflow/task/evss/upload'
require 'workflow/task/common/clean_all_files'
require 'workflow/task/common/datestamp_pdf_task'

class EVSS::Workflow < Workflow::File
  run Workflow::Task::Common::MoveToLTS
  run Workflow::Task::EVSS::Upload
  run Workflow::Task::Common::CleanAllFiles
end
