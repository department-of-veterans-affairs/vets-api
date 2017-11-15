# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Preneeds::PreneedAttachmentHash do
  include ActionDispatch::TestProcess

  let(:preneed_attachment) do
    create(:preneed_attachment)
  end

  describe '#get_file' do
    it 'should store the file and set the file_data' do
      set_file_data
      expect(preneed_attachment.parsed_file_data['filename']).to eq('extras.pdf')
    end
  end

  describe '#get_file' do
    it 'should get the file from storage' do
      set_file_data
      preneed_attachment.save!
      preneed_attachment2 = described_class.find(preneed_attachment.id)
      file = preneed_attachment2.get_file

      expect(file.exists?).to eq(true)
    end
  end
end
