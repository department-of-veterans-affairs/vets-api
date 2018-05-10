# frozen_string_literal: true

require 'rails_helper'
require 'csv'

describe Vet360::Service do
  let(:user)    { build(:user, :loa3) }
  let(:status)  { 400 }
  let(:message) { 'the server responded with status 400' }
  let(:file)    { Rails.root.join('spec', 'support', 'vet360', 'api_response_error_messages.csv') }
  subject       { described_class.new(user) }

  describe '#handle_error' do
    before do
      allow_any_instance_of(Common::Client::Base).to receive_message_chain(:config, :base_path) { '' }
    end

    it 'maps the error codes returned from Vet360 to the appropriate vets-api error message', :aggregate_failures do
      CSV.foreach(file, headers: true) do |row|
        error = Common::Client::Errors::ClientError.new(message, status, body_for(row))
        code  = row['Message Code']

        expect { subject.send('handle_error', error) }.to raise_error do |e|
          p "Failing code: #{code}" if e.errors.first.code != "VET360_#{code}"

          expect(e.errors.first.code).to eq("VET360_#{code}")
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
        end
      end
    end
  end
end

def body_for(row)
  {
    'messages' => [
      {
        'code'     => row['Message Code'].to_s,
        'key'      => row['Message Key'].to_s,
        'severity' => 'ERROR',
        'text'     => row['Message Description'].to_s
      }
    ],
    'tx_audit_id' => '3773cd41-0958-4bbe-a035-16ae353cde03',
    'status'      => 'REJECTED'
  }
end
