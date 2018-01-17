# frozen_string_literal: true

class ClaimDocumentation::PensionBurial::File < FileUpload
  self.uploader = ::ClaimDocumentation::Uploader
  self.workflow = ::ClaimDocumentation::PensionBurial::Workflow
end
