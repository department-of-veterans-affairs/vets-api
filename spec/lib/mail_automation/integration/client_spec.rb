# frozen_string_literal: true

require 'rails_helper'
require 'mail_automation/client'

# rubocop:disable RSpec/FilePath
RSpec.describe MailAutomation::Client, :vcr do
  describe '#list_medication_requests' do
    context 'with a sleep apnea request' do
      subject(:client) do
        described_class.new({
                              claim_id: 1234,
                              file_number: 1234,
                              form526: {
                                form526: {
                                  disabilities: [{
                                    name: 'sleep apnea',
                                    diagnosticCode: 6847
                                  }]
                                }
                              },
                              form526_uploads: []
                            }).initiate_apcas_processing
      end

      it 'returns all entries in the response' do
        VCR.use_cassette('mail_automation/mas_initiate_apcas_request') do
          expect(subject.body['packetId']).to eq('12345')
        end
      end
    end
  end
end
# rubocop:enable RSpec/FilePath
