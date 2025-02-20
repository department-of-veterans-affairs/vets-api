# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::PreneedAttachmentHash do
  let(:preneed_attachment_hash) do
    build(:preneed_attachment_hash)
  end

  describe '#get_file' do
    it 'gets the file from the preneed attachment' do
      expect(preneed_attachment_hash.get_file.exists?).to be(true)
    end
  end

  describe '#to_attachment' do
    it 'converts to Preneed::Attachment' do
      attachment = preneed_attachment_hash.to_attachment

      expect(attachment.attachment_type.attachment_type_id).to eq(1)
      expect(attachment.file.filename).to eq(preneed_attachment_hash.get_file.filename)
      expect(attachment.name).to eq(preneed_attachment_hash.name)
    end
  end
end
