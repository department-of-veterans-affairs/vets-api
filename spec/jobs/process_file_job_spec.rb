# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessFileJob do
  class TestUploader < CarrierWave::Uploader::Base
    def store_dir
      'store'
    end

    def filename
      'filename'
    end
  end

  class TestUploader2 < CarrierWave::Uploader::Base
    after(:store, :callback)

    def store_dir
      'store'
    end

    def filename
      'filename'
    end

    def callback(file)
    end
  end

  let(:test_uploader) { TestUploader.new }

  def store_image
    test_uploader.store!(
      Rack::Test::UploadedFile.new('spec/fixtures/files/va.gif', 'image/gif')
    )
  end

  describe '#perform' do
    it 'should save the new processed file and delete the old file' do
      store_image
      test_class_string = double
      expect(test_class_string).to receive(:constantize).and_return(TestUploader2)

      expect_any_instance_of(TestUploader2).to receive(:callback)

      ProcessFileJob.new.perform(test_class_string, test_uploader.store_dir, test_uploader.filename)
    end
  end
end
