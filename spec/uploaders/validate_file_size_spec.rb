# frozen_string_literal: true

require 'rails_helper'

describe ValidateFileSize do
  class ValidateFileSizeTest < CarrierWave::Uploader::Base
    include ValidateFileSize

    MAX_FILE_SIZE = 10

    attr_reader :file

    def initialize(file_size)
      @file = OpenStruct.new({ size: file_size })
    end

    def store!(_)
      with_callbacks(:store, file) do
        'stored successfully'
      end
    end
  end

  it 'raises an error when the file is larger than MAX_FILE_SIZE megabytes' do
    subject = ValidateFileSizeTest.new(ValidateFileSizeTest::MAX_FILE_SIZE.megabytes + 1)
    expect { subject.store!('blah') }.to raise_error(CarrierWave::UploadError, 'File size larger than allowed')
  end
end
