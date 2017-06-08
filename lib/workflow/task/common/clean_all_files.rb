# frozen_string_literal: true
require 'workflow/task/shrine_file/base'

module Workflow::Task::Common
  class CleanAllFiles < Workflow::Task::ShrineFile::Base
    def run
      history.each(&:delete)
    end
  end
end
