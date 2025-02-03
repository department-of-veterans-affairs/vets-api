# frozen_string_literal: true

require 'rails_helper'
require 'vba_documents/object_store'

RSpec.describe VBADocuments::ObjectStore do
  before do
    @resource = instance_double(Aws::S3::Resource)
    @client = instance_double(Aws::S3::Client)
    @bucket = instance_double(Aws::S3::Bucket)
    @object = instance_double(Aws::S3::Object)
    allow(Aws::S3::Resource).to receive(:new).and_return(@resource)
    allow(Aws::S3::Client).to receive(:new).and_return(@client)
  end

  describe '#bucket' do
    it 'returns a bucket' do
      expect(@resource).to receive(:bucket).and_return(@bucket)
      described_class.new.bucket
    end
  end

  describe '#object' do
    it 'returns an object' do
      expect(@resource).to receive(:bucket).and_return(@bucket)
      expect(@bucket).to receive(:object).and_return(@object)
      described_class.new.object('foo')
    end
  end

  describe '#delete' do
    it 'deletes the object' do
      v1 = instance_double(Aws::S3::ObjectVersion)
      v2 = instance_double(Aws::S3::ObjectVersion)
      expect(@resource).to receive(:bucket).and_return(@bucket)
      expect(@bucket).to receive(:object_versions).and_return([v1, v2])
      expect(v1).to receive(:delete)
      expect(v2).to receive(:delete)
      described_class.new.delete('foo')
    end
  end

  describe '#first_version' do
    it 'returns the earliest available version' do
      v1 = instance_double(Aws::S3::ObjectVersion)
      v2 = instance_double(Aws::S3::ObjectVersion)
      t1 = 1.minute.ago
      t2 = 2.minutes.ago
      expect(v1).to receive(:last_modified).and_return(t1)
      expect(v2).to receive(:last_modified).and_return(t2)
      expect(@resource).to receive(:bucket).and_return(@bucket)
      expect(@bucket).to receive(:object_versions).and_return([v1, v2])
      result = described_class.new.first_version('foo')
      expect(result).to eq(v2)
    end
  end

  describe '#download' do
    it 'downloads the specified version' do
      v1 = instance_double(Aws::S3::ObjectVersion)
      expect(v1).to receive(:bucket_name).and_return('my-bucket')
      expect(v1).to receive(:object_key).and_return('foo')
      expect(v1).to receive(:version_id).and_return('123456')
      expect(@client).to receive(:get_object).with(hash_including(
                                                     bucket: 'my-bucket',
                                                     key: 'foo',
                                                     version_id: '123456',
                                                     response_target: '/tmp/foobar'
                                                   ))
      described_class.new.download(v1, '/tmp/foobar')
    end
  end
end
