# frozen_string_literal: true

require 'rails_helper'
require 'vba_documents/object_store'

RSpec.describe VBADocuments::ObjectStore do

  before(:each) do
    resource = instance_double(Aws::S3::Resource)
    client = instance_double(Aws::S3::Client)
  end

  describe '#bucket' do
  end

  describe '#object' do
  end

  describe '#first_version' do
  end

  describe '#download' do
  end
end

