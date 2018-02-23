# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LogMetrics do
  class LogMetricsUploader < CarrierWave::Uploader::Base
    include LogMetrics
  end

  let(:test_uploader) { LogMetricsUploader.new }

  it 'should log metrics of uploaded file' do
    expect(StatsD).to receive(:measure).with('api.upload.log_metrics_uploader.size', 90_537)
    expect(StatsD).to receive(:measure).with('api.upload.log_metrics_uploader.content_type', 'image/gif')

    test_uploader.store!(
      Rack::Test::UploadedFile.new('spec/fixtures/files/va.gif', 'image/gif')
    )
  end
end
