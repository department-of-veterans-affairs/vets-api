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
        }
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
  end
end
