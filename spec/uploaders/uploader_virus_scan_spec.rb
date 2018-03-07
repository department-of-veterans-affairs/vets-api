# frozen_string_literal: true

require 'rails_helper'

describe UploaderVirusScan do
  class UploaderVirusScanTest < CarrierWave::Uploader::Base
    include UploaderVirusScan
  end
  let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/va.gif', 'image/gif') }

  def store_image
    UploaderVirusScanTest.new.store!(file)
  end

  context 'in production' do
    before do
      expect(Common::VirusScan).to receive(:scan).and_return(OpenStruct.new(result))
    end

    context 'with no virus' do
      let(:result) do
        {
          safe?: true
        }
      end

      it 'should run the virus scan' do
        expect(Rails.env).to receive(:production?).and_return(true)

        store_image
      end
    end

    context 'with a virus' do
      let(:result) do
        {
          safe?: false,
          body: 'virus found'
        }
      end

      it 'should raise an error' do
        expect(Rails.env).to receive(:production?).and_return(true)
        expect(file).to receive(:delete)

        expect { store_image }.to raise_error(
          UploaderVirusScan::VirusFoundError, 'virus found'
        )
      end
    end
  end
end
