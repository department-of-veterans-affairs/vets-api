# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::VHA107959a do
  let(:data) do
    {
      'primary_contact_info' => {
        'name' => {
          'first' => 'Veteran',
          'last' => 'Surname'
        },
        'email' => false
      },
      'applicant_member_number' => '123456789',
      'applicant_name' => { 'first' => 'John', 'middle' => 'P', 'last' => 'Doe' },
      'applicant_address' => { 'country' => 'USA', 'postal_code' => '12345' },
      'form_number' => '10-7959A',
      'veteran_supporting_documents' => [
        { 'confirmation_code' => 'abc123' },
        { 'confirmation_code' => 'def456' }
      ]
    }
  end
  let(:vha_10_7959a) { described_class.new(data) }

  describe '#metadata' do
    it 'returns metadata for the form' do
      metadata = vha_10_7959a.metadata

      expect(metadata).to include(
        'veteranFirstName' => 'John',
        'veteranLastName' => 'Doe',
        'zipCode' => '12345',
        'country' => 'USA',
        'source' => 'VA Platform Digital Forms',
        'docType' => '10-7959A',
        'ssn_or_tin' => '123456789',
        'fileNumber' => '123456789',
        'businessLine' => 'CMP',
        'primaryContactInfo' => {
          'name' => {
            'first' => 'Veteran',
            'last' => 'Surname'
          },
          'email' => false
        },
        'primaryContactEmail' => 'false'
      )
    end
  end

  describe '#track_email_usage' do
    let(:statsd_key) { 'api.ivc_champva_form.10_7959a' }

    context 'when email is used' do
      let(:data) { { 'primary_contact_info' => { 'email' => 'test@example.com' } } }

      it 'increments the StatsD for email used and logs the info' do
        expect(StatsD).to receive(:increment).with("#{statsd_key}.yes")
        expect(Rails.logger).to receive(:info).with('IVC ChampVA Forms - 10-7959A Email Used', email_used: 'yes')
        vha_10_7959a.track_email_usage
      end
    end

    context 'when email is not used' do
      let(:data) { { 'primary_contact_info' => {} } }

      it 'increments the StatsD for email not used and logs the info' do
        expect(StatsD).to receive(:increment).with("#{statsd_key}.no")
        expect(Rails.logger).to receive(:info).with('IVC ChampVA Forms - 10-7959A Email Used', email_used: 'no')
        vha_10_7959a.track_email_usage
      end
    end
  end

  it 'is not past OMB expiration date' do
    # Update this date string to match the current PDF OMB expiration date:
    omb_expiration_date = Date.strptime('12312027', '%m%d%Y')
    error_message = <<~MSG
      If this test is failing it likely means the form 10-7959a PDF has reached
      OMB expiration date. Please see ivc_champva module README for details on updating the PDF file.
    MSG

    expect(omb_expiration_date.past?).to be(false), error_message
  end
end
