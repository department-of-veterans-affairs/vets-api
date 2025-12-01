# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/profile/v3/health_benefit_bio_response'

describe VAProfile::Profile::V3::HealthBenefitBioResponse do
  subject { described_class.new(response) }

  let(:response) do
    double(
      'Faraday::Response',
      status: 200,
      body: {
        'profile' => {
          'health_benefit' => {
            'associated_persons' => [{
              'contact_type' => contact_type
            }]
          }
        },
        'messages' => [{
          'code' => 'MVI201',
          'key' => 'MviNotFound',
          'text' => 'The person with the identifier requested was not found in MVI.'
        }]
      },
      response_headers: {
        'vaprofiletxauditid' => 'abc123'
      }
    )
  end

  describe 'Emergency contact' do
    let(:contact_type) { 'Emergency Contact' }

    it 'includes contact' do
      expect(subject.contacts).not_to be_empty
    end
  end

  describe 'Other emergency contact' do
    let(:contact_type) { 'Other emergency contact' }

    it 'includes contact' do
      expect(subject.contacts).not_to be_empty
    end
  end

  describe 'Primary Next of Kin' do
    let(:contact_type) { 'Primary Next of Kin' }

    it 'includes contact' do
      expect(subject.contacts).not_to be_empty
    end
  end

  describe 'Other Next of Kin' do
    let(:contact_type) { 'Other Next of Kin' }

    it 'includes contact' do
      expect(subject.contacts).not_to be_empty
    end
  end

  describe 'Invalid contact type' do
    let(:contact_type) { 'Invalid type' }

    it 'does not include contact' do
      expect(subject.contacts).to be_empty
    end

    it 'includes the invalid type in meta[:contact_types]' do
      expect(subject.meta[:contact_types]).to include('Invalid type')
    end
  end

  describe 'response metadata' do
    let(:contact_type) { 'Other Next of Kin' }

    it 'includes the code from the upstream system' do
      expect(subject.meta[:code]).to eq('MVI201')
    end

    it 'includes the response HTTP status code from the upstream system' do
      expect(subject.meta[:status]).to eq(200)
    end

    it 'includes the first message returned from the response body' do
      message = subject.meta[:message]
      expect(message).to match(/^MVI201/)
      expect(message).to match(/MviNotFound/)
      expect(message).to match(/not found in MVI.$/)
    end

    it 'includes the contact_type names' do
      expect(subject.meta[:contact_types]).to include('Other Next of Kin')
    end

    it 'includes the number of relevant contacts surfaced' do
      expect(subject.meta[:contact_count]).to eq(1)
    end

    it 'includes an audit id from the upstream system' do
      expect(subject.meta[:va_profile_tx_audit_id]).to eq('abc123')
    end
  end
end
