# frozen_string_literal: true

require 'rails_helper'
require 'support/1010_forms/shared_examples/attachment_serializer'

describe HCAAttachmentSerializer, type: :serializer do
  it_behaves_like '1010 forms attachment serializer' do
    let(:resource_name) { 'hca_attachment' }
  end
end
