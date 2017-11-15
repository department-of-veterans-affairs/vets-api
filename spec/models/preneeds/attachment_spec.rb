# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Preneeds::Attachment do
  let(:attachment) do
    build(:preneed_attachment_hash).to_attachment
  end
  let(:uuid) do
    "62803e79-8181-402a-95dc-a014653f52bb"
  end

  describe '#as_eoas' do
    it 'should return the eoas hash' do
      allow(SecureRandom).to receive(:uuid).and_return(uuid)

      expect(attachment.as_eoas).to eq(
        {:attachmentType=>{:attachmentTypeId=>1}, :dataHandler=>uuid, :description=>"extras.pdf", :sendingSource=>"vets.gov"}
      )
    end
  end
end
