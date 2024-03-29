# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LogMetrics do
  class LogMetricsUploader < CarrierWave::Uploader::Base
    include LogMetrics
  end

  module MyApp
    class LogMetricsUploader < CarrierWave::Uploader::Base
      include LogMetrics
    end
  end

  let(:test_uploader) { LogMetricsUploader.new }

  it 'logs metrics of uploaded file' do
    expect(StatsD).to receive(:measure).with(
      'api.upload.log_metrics_uploader.size',
      90_537,
      tags: ['content_type:gif']
    )

    test_uploader.store!(
      Rack::Test::UploadedFile.new('spec/fixtures/files/va.gif', 'image/gif')
    )
  end

  describe 'metric key' do
    let(:test_uploader) { MyApp::LogMetricsUploader.new }

    context 'with module namespace' do
      it 'logs metric with module name' do
        expect(StatsD).to receive(:measure).with(
          'api.upload.my_app_log_metrics_uploader.size',
          90_537,
          tags: ['content_type:gif']
        )

        test_uploader.store!(
          Rack::Test::UploadedFile.new('spec/fixtures/files/va.gif', 'image/gif')
        )
      end
    end
  end
end
