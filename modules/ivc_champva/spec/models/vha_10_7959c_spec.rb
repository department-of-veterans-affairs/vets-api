# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::VHA107959c do
  let(:data) do
    {
      'primary_contact_info' => {
        'name' => {
          'first' => 'Veteran',
          'last' => 'Surname'
        },
        'email' => false
      },
      'applicant_name' => {
        'first' => 'John',
        'middle' => 'P',
        'last' => 'Doe'
      },
      'applicant_address' => {
        'country' => 'USA',
        'postal_code' => '12345'
      },
      'applicant_ssn' => '123456789',
      'form_number' => '10-7959C',
      'veteran_supporting_documents' => [
        { 'confirmation_code' => 'abc123' },
        { 'confirmation_code' => 'def456' }
      ],
      'applicant_email' => 'applicant@email.gov'
    }
  end
  let(:vha107959c) { described_class.new(data) }
  let(:uuid) { SecureRandom.uuid }
  let(:instance) { IvcChampva::VHA107959c.new(data) }

  before do
    allow(instance).to receive_messages(uuid:, get_attachments: [])
  end

  describe '#metadata' do
    it 'returns metadata for the form' do
      metadata = vha107959c.metadata

      expect(metadata).to include(
        'veteranFirstName' => 'John',
        'veteranMiddleName' => 'P',
        'veteranLastName' => 'Doe',
        'fileNumber' => '123456789',
        'zipCode' => '12345',
        'ssn_or_tin' => '123456789',
        'country' => 'USA',
        'source' => 'VA Platform Digital Forms',
        'docType' => '10-7959C',
        'businessLine' => 'CMP',
        'primaryContactInfo' => {
          'name' => {
            'first' => 'Veteran',
            'last' => 'Surname'
          },
          'email' => false
        },
        'primaryContactEmail' => 'false',
        'applicantEmail' => 'applicant@email.gov'
      )
    end
  end

  describe '#method_missing' do
    it 'returns the method name and arguments' do
      result = instance.some_missing_method('arg1', 'arg2')
      expect(result).to eq({ method: :some_missing_method, args: %w[arg1 arg2] })
    end
  end

  describe '#handle_attachments' do
    let(:file_path) { "#{uuid}_vha_10_7959c-tmp.pdf" }

    it 'renames the file and returns the new file path' do
      allow(File).to receive(:rename)
      result = instance.handle_attachments(file_path)
      expect(result).to eq(["#{uuid}_vha_10_7959c-tmp.pdf"])
    end
  end

  describe '#track_email_usage' do
    let(:statsd_key) { 'api.ivc_champva_form.10_7959c' }
    let(:vha_10_7959c) { described_class.new(data) }

    context 'when email is used' do
      let(:data) { { 'primary_contact_info' => { 'email' => 'test@example.com' } } }

      it 'increments the StatsD for email used and logs the info' do
        expect(StatsD).to receive(:increment).with("#{statsd_key}.yes")
        expect(Rails.logger).to receive(:info).with('IVC ChampVA Forms - 10-7959C Email Used', email_used: 'yes')
        vha_10_7959c.track_email_usage
      end
    end

    context 'when email is not used' do
      let(:data) { { 'primary_contact_info' => {} } }

      it 'increments the StatsD for email not used and logs the info' do
        expect(StatsD).to receive(:increment).with("#{statsd_key}.no")
        expect(Rails.logger).to receive(:info).with('IVC ChampVA Forms - 10-7959C Email Used', email_used: 'no')
        vha_10_7959c.track_email_usage
      end
    end
  end

  it 'is not past OMB expiration date' do
    # Update this date string to match the current PDF OMB expiration date:
    omb_expiration_date = Date.strptime('12312027', '%m%d%Y')
    error_message = <<~MSG
      If this test is failing it likely means the form 10-7959c PDF has reached
      OMB expiration date. Please see ivc_champva module README for details on updating the PDF file.
    MSG

    expect(omb_expiration_date.past?).to be(false), error_message
  end
end
