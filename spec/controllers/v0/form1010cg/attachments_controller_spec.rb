# frozen_string_literal: true

require 'rails_helper'
require 'controllers/concerns/form_attachment_create_spec'

RSpec.describe V0::Form1010cg::AttachmentsController, type: :controller do
  it_behaves_like 'a FormAttachmentCreate controller'
end
