# frozen_string_literal: true

require 'rails_helper'

describe UploaderVirusScan, :uploader_helpers do
  class UploaderVirusScanTest < CarrierWave::Uploader::Base
    include UploaderVirusScan
  end
  let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/va.gif', 'image/gif') }

  def store_image
    UploaderVirusScanTest.new.store!(file)
  end

  context 'in production' do
    stub_virus_scan

    context 'with no virus' do
      it 'runs the virus scan' do
        expect(Rails.env).to receive(:production?).and_return(true)

        store_image
      end
    end

    context 'with a virus' do
      let(:result) { false }

      it 'raises an error' do
        allow(Common::VirusScan).to receive(:scan).and_return(false)
        expect(Rails.env).to receive(:production?).and_return(true)
        expect(file).to receive(:delete)

        expect { store_image }.to raise_error(
          UploaderVirusScan::VirusFoundError
        )
      end
    end
  end
end
