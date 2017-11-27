# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Preneeds::PreneedAttachmentHash do
  let(:preneed_attachment_hash) do
    build(:preneed_attachment_hash)
  end

  describe '#get_file' do
    it 'should get the file from the preneed attachment' do
      expect(preneed_attachment_hash.get_file.exists?).to eq(true)
    end
  end

  describe '#to_attachment' do
    it 'should convert to Preneed::Attachment' do
      attachment = preneed_attachment_hash.to_attachment

      expect(attachment.attachment_type.attachment_type_id).to eq(1)
      expect(attachment.file.filename).to eq(preneed_attachment_hash.get_file.filename)
    end
  end
end
