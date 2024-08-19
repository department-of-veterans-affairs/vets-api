# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::VHA1010d do
  let(:data) do
    {
      'primary_contact_info' => {
        'name' => {
          'first' => 'Veteran',
          'last' => 'Surname'
        },
        'email' => false
      },
      'veteran' => {
        'full_name' => { 'first' => 'John', 'middle' => 'P', 'last' => 'Doe' },
        'va_claim_number' => '123456789',
        'address' => { 'country' => 'USA', 'postal_code' => '12345' }
      },
      'form_number' => 'VHA1010d',
      'veteran_supporting_documents' => [
        { 'confirmation_code' => 'abc123' },
        { 'confirmation_code' => 'def456' }
      ]
    }
  end
  let(:vha1010d) { described_class.new(data) }
  let(:logger) { instance_spy(Logger) }

  before { allow(Rails.logger).to receive(:info) }

  describe '#track_user_identity' do
    it 'returns the right data' do
      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json')
      data = JSON.parse(fixture_path.read)

      described_class.new(data).track_user_identity

      expect(Rails.logger).to have_received(:info)
        .with('IVC ChampVA Forms - 10-10D Submission User Identity', { identity: 'applicant' })
    end
  end

  describe '#metadata' do
    it 'returns metadata for the form' do
      metadata = vha1010d.metadata

      expect(metadata).to include(
        'veteranFirstName' => 'John',
        'veteranLastName' => 'Doe',
        'fileNumber' => '123456789',
        'zipCode' => '12345',
        'country' => 'USA',
        'source' => 'VA Platform Digital Forms',
        'docType' => 'VHA1010d',
        'businessLine' => 'CMP',
        'primaryContactInfo' => {
          'name' => {
            'first' => 'Veteran',
            'last' => 'Surname'
          },
          'email' => false
        }
      )
    end
  end

  describe '#track_email_usage' do
    let(:statsd_key) { 'api.ivc_champva_form.10_10d' }
    let(:vha_10_10d) { described_class.new(data) }

    context 'when email is used' do
      let(:data) { { 'primary_contact_info' => { 'email' => 'test@example.com' } } }

      it 'increments the StatsD for email used and logs the info' do
        expect(StatsD).to receive(:increment).with("#{statsd_key}.yes")
        expect(Rails.logger).to receive(:info).with('IVC ChampVA Forms - 10-10D Email Used', email_used: 'yes')
        vha_10_10d.track_email_usage
      end
    end

    context 'when email is not used' do
      let(:data) { { 'primary_contact_info' => {} } }

      it 'increments the StatsD for email not used and logs the info' do
        expect(StatsD).to receive(:increment).with("#{statsd_key}.no")
        expect(Rails.logger).to receive(:info).with('IVC ChampVA Forms - 10-10D Email Used', email_used: 'no')
        vha_10_10d.track_email_usage
      end
    end
  end
end
