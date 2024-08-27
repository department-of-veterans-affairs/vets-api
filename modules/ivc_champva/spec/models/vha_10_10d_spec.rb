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

  describe '#desired_stamps' do
    context 'when sponsor is deceased' do
      let(:data_with_deceased_sponsor) do
        data.merge(
          'veteran' => data['veteran'].merge('sponsor_is_deceased' => true),
          'applicants' => [
            {
              'applicant_address' => {
                'country' => 'Canada'
              }
            }
          ]
        )
      end
      let(:vha1010d_with_deceased_sponsor) { described_class.new(data_with_deceased_sponsor) }

      it 'returns correct stamps including the first applicant country' do
        expect(vha1010d_with_deceased_sponsor.desired_stamps).to include(
          hash_including(coords: [520, 470], text: 'Canada', page: 0)
        )
      end
    end

    context 'when sponsor is not deceased' do
      it 'returns correct stamps including veteran country and the first applicant country' do
        expect(vha1010d.desired_stamps).to include(
          hash_including(coords: [520, 590], text: 'USA', page: 0),
          hash_including(coords: [520, 470], text: nil, page: 0) # Assuming no applicants for simplicity
        )
      end
    end

    context 'with multiple applicants' do
      let(:data_with_multiple_applicants) do
        data.merge(
          'applicants' => [
            { 'applicant_address' => { 'country' => 'Canada' } },
            { 'applicant_address' => { 'country' => 'Mexico' } }
          ]
        )
      end
      let(:vha1010d_with_multiple_applicants) { described_class.new(data_with_multiple_applicants) }

      it 'returns stamps for all applicants' do
        stamps = vha1010d_with_multiple_applicants.desired_stamps
        expect(stamps.count { |stamp| stamp[:text] == 'Canada' || stamp[:text] == 'Mexico' }).to eq(2)
        expect(stamps).to include(
          hash_including(coords: [520, 470], text: 'Canada', page: 0),
          hash_including(coords: [520, 354], text: 'Mexico', page: 0)
        )
      end
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
