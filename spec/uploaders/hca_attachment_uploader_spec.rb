# frozen_string_literal: true

require 'rails_helper'
require 'carrierwave/test/matchers'

RSpec.describe HCAAttachmentUploader, type: :uploader do
  include CarrierWave::Test::Matchers

  let(:uploader) { described_class.new(guid) }

  let(:guid) { 'test-guid' }
  let(:file) do
    Rack::Test::UploadedFile.new(
      Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.png'),
      'image/png'
    )
  end

  before do
    CarrierWave.configure do |config|
      config.enable_processing = true
    end
    uploader.store!(file)
  end

  after do
    uploader.remove!
    CarrierWave.configure do |config|
      config.enable_processing = false
    end
  end

  describe '#initialize' do
    context 'when Rails.env is production' do
      let(:settings) do
        OpenStruct.new(
          aws_access_key_id: 'access-key',
          aws_secret_access_key: 'shh-its-a-secret',
          region: 'my-region',
          bucket: 'bucket/path'
        )
      end

      before do
        allow(Settings).to receive(:hca).and_return(OpenStruct.new(s3: settings))
        allow(Rails.env).to receive(:production?).and_return(true)
      end

      it 'sets AWS config with production settings' do
        expect_any_instance_of(HCAAttachmentUploader).to receive(:set_aws_config).with(
          Settings.hca.s3.aws_access_key_id,
          Settings.hca.s3.aws_secret_access_key,
          Settings.hca.s3.region,
          Settings.hca.s3.bucket
        )

        described_class.new('test-guid')
      end
    end

    context 'when Rails.env is not production' do
      before do
        allow(Rails.env).to receive(:production?).and_return(false)
      end

      it 'does not set AWS config' do
        expect_any_instance_of(HCAAttachmentUploader).not_to receive(:set_aws_config)

        described_class.new('test-guid')
      end
    end
  end

  describe '#size_range' do
    it 'has a valid size range' do
      expect(uploader.size_range).to eq((1.byte)...(10.megabytes))
    end
  end

  describe '#extension_allowlist' do
    context ':hca_heif_attachments_enabled enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:hca_heif_attachments_enabled).and_return(true)
      end

      it 'allows valid file extensions' do
        expect(uploader.extension_allowlist).to include('pdf', 'doc', 'docx', 'jpg', 'jpeg', 'rtf', 'png', 'heic',
                                                        'heif')
      end

      it 'does not allow invalid file extensions' do
        expect(uploader.extension_allowlist).not_to include('exe', 'bat', 'zip')
      end
    end

    context ':hca_heif_attachments_enabled disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:hca_heif_attachments_enabled).and_return(false)
      end

      it 'allows valid file extensions - no heic files' do
        expect(uploader.extension_allowlist).to include('pdf', 'doc', 'docx', 'jpg', 'jpeg', 'rtf', 'png')
      end

      it 'does not allow invalid file extensions' do
        expect(uploader.extension_allowlist).not_to include('exe', 'bat', 'zip', 'heic', 'heif')
      end
    end
  end

  describe '#store_dir' do
    it 'sets the correct store directory' do
      expect(uploader.store_dir).to eq('hca_attachments')
    end
  end

  describe '#filename' do
    it 'sets the filename to the guid' do
      expect(uploader.filename).to eq(guid)
    end
  end

  describe 'processing' do
    context 'when the file is a PNG' do
      it 'converts the file to JPG' do
        expect(uploader).to receive(:convert).with('jpg')

        uploader.store!(file)
      end
    end

    context 'when the file is a HEIC' do
      let(:file) do
        Rack::Test::UploadedFile.new(
          Rails.root.join('spec', 'fixtures', 'files', 'steelers.heic'),
          'image/heic'
        )
      end

      context ':hca_heif_attachments_enabled enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:hca_heif_attachments_enabled).and_return(true)
        end

        it 'converts the file to jpg' do
          expect(uploader).to receive(:convert).with('jpg')

          uploader.store!(file)
        end
      end

      context ':hca_heif_attachments_enabled disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:hca_heif_attachments_enabled).and_return(false)
        end

        it 'raises invalid file type error' do
          expect { uploader.store!(file) }.to raise_error do |error|
            expect(error).to be_instance_of(CarrierWave::IntegrityError)
            expect(error.message).to eq(
              'You can’t upload "heic" files. The allowed file types are: pdf, doc, docx, jpg, jpeg, rtf, png'
            )
          end
        end
      end
    end

    context 'when the file is a HEIF' do
      let(:file) do
        Rack::Test::UploadedFile.new(
          Rails.root.join('spec', 'fixtures', 'files', 'steelers.heif'),
          'image/heif'
        )
      end

      context ':hca_heif_attachments_enabled enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:hca_heif_attachments_enabled).and_return(true)
        end

        it 'converts the file to jpg' do
          expect(uploader).to receive(:convert).with('jpg')

          uploader.store!(file)
        end
      end

      context ':hca_heif_attachments_enabled disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:hca_heif_attachments_enabled).and_return(false)
        end

        it 'raises invalid file type error' do
          expect { uploader.store!(file) }.to raise_error do |error|
            expect(error).to be_instance_of(CarrierWave::IntegrityError)
            expect(error.message).to eq(
              'You can’t upload "heif" files. The allowed file types are: pdf, doc, docx, jpg, jpeg, rtf, png'
            )
          end
        end
      end
    end
  end
end
