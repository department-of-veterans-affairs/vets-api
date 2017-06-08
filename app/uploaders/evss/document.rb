# frozen_string_literal: true
class Evss::Document < FileUpload
  self.uploader = EVSS::Uploader
  self.workflow = EVSS::Workflow
end
