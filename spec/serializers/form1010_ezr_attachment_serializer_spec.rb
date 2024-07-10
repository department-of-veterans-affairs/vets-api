# frozen_string_literal: true

require 'rails_helper'
require 'support/1010_forms/shared_examples/attachment_serializer'

describe Form1010EzrAttachmentSerializer, type: :serializer do
  it_behaves_like '1010 forms attachment serializer' do
    let(:resource_name) { 'form1010_ezr_attachment' }
  end
end
