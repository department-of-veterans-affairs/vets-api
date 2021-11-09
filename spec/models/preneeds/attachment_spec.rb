# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::Attachment do
  let(:attachment) do
    build(:preneed_attachment_hash).to_attachment
  end
  let(:hex) do
    'de4761e83497fd19b7bceb3315dc5efb'
  end

  describe '#as_eoas' do
    it 'returns the eoas hash' do
      allow(SecureRandom).to receive(:hex).and_return(hex)

      expect(attachment.as_eoas).to eq(
        attachmentType: { attachmentTypeId: 1 },
        dataHandler: {
          'inc:Include': '',
          attributes!: {
            'inc:Include': {
              href: "cid:#{hex}", 'xmlns:inc': 'http://www.w3.org/2004/08/xop/include'
            }
          }
        },
        description: 'dd214a.pdf',
        sendingName: 'vets.gov',
        sendingSource: 'vets.gov'
      )
    end
  end
end
