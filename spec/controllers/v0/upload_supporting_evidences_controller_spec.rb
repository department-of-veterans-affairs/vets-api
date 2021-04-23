# frozen_string_literal: true

require 'rails_helper'
require 'controllers/concerns/form_attachment_create_spec'

RSpec.describe V0::UploadSupportingEvidencesController, type: :controller do
  it_behaves_like 'a FormAttachmentCreate controller', user_factory: :loa1
end
