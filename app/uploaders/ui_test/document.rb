# frozen_string_literal: true
class UITest::Document < FileUpload
  self.uploader = UITest::Uploader
  self.workflow = UITest::Workflow
end
