# frozen_string_literal: true

require 'rails_helper'
require 'support/1010_forms/shared_examples/attachment_serializer'

RSpec.describe Form1010cg::AttachmentSerializer do
  it_behaves_like '1010 forms attachment serializer' do
    let(:resource_name) { 'form1010cg_attachment' }
  end
end
