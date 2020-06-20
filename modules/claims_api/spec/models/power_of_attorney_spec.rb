# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::PowerOfAttorney, type: :model do
  let(:pending_record) { create(:power_of_attorney) }

  describe 'encrypted attributes' do
    it 'does the thing' do
      expect(subject).to encrypt_attr(:form_data)
      expect(subject).to encrypt_attr(:auth_headers)
    end
  end

  describe 'encrypted attribute' do
    it 'does the thing' do
      expect(subject).to encrypt_attr(:file_data)
    end
  end

  describe '#set_file_data!' do
    it 'stores the file_data and give me a full evss document' do
      attachment = build(:power_of_attorney)

      file = Rack::Test::UploadedFile.new(
        "#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf"
      )

      attachment.set_file_data!(file, 'docType')
      attachment.save!
      attachment.reload

      expect(attachment.file_data).to have_key('filename')
      expect(attachment.file_data).to have_key('doc_type')

      expect(attachment.file_name).to eq(attachment.file_data['filename'])
      expect(attachment.document_type).to eq(attachment.file_data['doc_type'])
    end
  end

  describe 'pending?' do
    context 'no pending records' do
      it 'is false' do
        expect(described_class.pending?('123')).to be(false)
      end
    end

    context 'with pending records' do
      it 'truthies and return the record' do
        result = described_class.pending?(pending_record.id)
        expect(result).to be_truthy
        expect(result.id).to eq(pending_record.id)
      end
    end
  end

  describe 'inserting the signature files' do
    let(:power_of_attorney) { create(:power_of_attorney) }

    describe 'with signatures' do
      let(:signature_path) { Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'signature.png') }

      before do
        Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
        b64_image = File.read('modules/claims_api/spec/fixtures/signature_b64.txt')
        power_of_attorney.form_data['signatures'] = {}
        power_of_attorney.form_data['signatures']['veteran'] = b64_image
        power_of_attorney.form_data['signatures']['representative'] = b64_image
        power_of_attorney.save
      end

      after do
        Timecop.return
      end

      it 'adds signature to pdf page 1' do
        expected_path = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '2122', 'page_1_signed.pdf')
        signed_path = power_of_attorney.insert_signatures(1, signature_path, signature_path)
        generated_pdf_md5 = Digest::MD5.digest(File.read(signed_path))
        expected_pdf_md5 = Digest::MD5.digest(File.read(expected_path))
        File.delete(signed_path) if File.exist?(signed_path)
        expect(generated_pdf_md5).not_to eq(nil)
        expect(generated_pdf_md5).to eq(expected_pdf_md5)
      end

      it 'adds signature to pdf page 2' do
        expected_path = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '2122', 'page_2_signed.pdf')
        signed_path = power_of_attorney.insert_signatures(2, signature_path, signature_path)
        generated_pdf_md5 = Digest::MD5.digest(File.read(signed_path))
        expected_pdf_md5 = Digest::MD5.digest(File.read(expected_path))
        File.delete(signed_path) if File.exist?(signed_path)
        expect(generated_pdf_md5).not_to eq(nil)
        expect(generated_pdf_md5).to eq(expected_pdf_md5)
      end

      it 'rescues a bad image' do
        bad_image_path = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '2122', 'page_2_signed.pdf')
        expect do
          power_of_attorney.insert_signatures(2, bad_image_path, bad_image_path)
        end.to raise_error(ClaimsApi::StampSignatureError)
      end

      it 'converts b64 image data to image files' do
        expect(power_of_attorney).to receive(:convert_base64_data_to_image)
          .with('veteran')
          .and_return('tmp/path1')
        expect(power_of_attorney).to receive(:convert_base64_data_to_image)
          .with('representative')
          .and_return('tmp/path2')
        signature_paths = power_of_attorney.convert_signatures_to_images
        expect(signature_paths).to eq({ veteran: 'tmp/path1', representative: 'tmp/path2' })
      end

      it 'signs both pdfs and returns the paths' do
        paths = power_of_attorney.sign_pdf
        expect(paths[:page1].split('.').last).to eq('pdf')
        expect(paths[:page2].split('.').last).to eq('pdf')
        expect(paths[:page1]).not_to eq(paths[:page2])
      end

      it 'creates the signature image file' do
        power_of_attorney.create_signature_image('veteran')
        expected_path = "/tmp/veteran_#{power_of_attorney.id}_signature.png"
        expect(power_of_attorney.signature_image_paths['veteran']).to eq(expected_path)
      end
    end
  end
end
