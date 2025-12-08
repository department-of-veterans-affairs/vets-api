# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'form model 10_7959C' do |form_number|
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
      'certifier_role' => 'applicant',
      'applicant_ssn' => '123456789',
      'form_number' => form_number,
      'veteran_supporting_documents' => [
        { 'confirmation_code' => 'abc123' },
        { 'confirmation_code' => 'def456' }
      ],
      'applicant_email' => 'applicant@email.gov'
    }
  end
  let(:vha107959c) { described_class.new(data) }
  let(:uuid) { SecureRandom.uuid }
  let(:statsd_key) { described_class::STATS_KEY }

  before do
    allow(vha107959c).to receive_messages(get_attachments: [])
  end

  describe '#metadata' do
    context 'when champva_update_metadata_keys flipper is enabled' do
      it 'returns metadata for the form' do
        allow(Flipper).to receive(:enabled?).with(:champva_update_metadata_keys).and_return(true)
        metadata = vha107959c.metadata

        expect(metadata).to include(
          'sponsorFirstName' => 'John',
          'sponsorMiddleName' => 'P',
          'sponsorLastName' => 'Doe',
          'fileNumber' => '123456789',
          'zipCode' => '12345',
          'ssn_or_tin' => '123456789',
          'country' => 'USA',
          'source' => 'VA Platform Digital Forms',
          'docType' => form_number,
          'businessLine' => 'CMP',
          'primaryContactInfo' => {
            'name' => {
              'first' => 'Veteran',
              'last' => 'Surname'
            },
            'email' => false
          },
          'primaryContactEmail' => 'false',
          'beneficiaryEmail' => 'applicant@email.gov'
        )
      end
    end

    context 'when champva_update_metadata_keys flipper is disabled' do
      it 'returns metadata for the form' do
        allow(Flipper).to receive(:enabled?).with(:champva_update_metadata_keys).and_return(false)
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
          'docType' => form_number,
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
  end

  describe '#track_user_identity' do
    it 'increments the StatsD for user identity and logs the info' do
      expect(StatsD).to receive(:increment).with("#{statsd_key}.#{data['certifier_role']}")
      expect(Rails.logger)
        .to receive(:info)
        .with("IVC ChampVA Forms - #{form_number} Submission User Identity", identity: data['certifier_role'])

      vha107959c.track_user_identity
    end
  end

  describe '#track_current_user_loa' do
    context 'when current loa is present' do
      it 'increments the StatsD for user loa and logs the info' do
        mock_user = double(loa: double)
        allow(mock_user.loa).to receive(:[]).with(:current).and_return(3)

        expect(StatsD).to receive(:increment).with("#{statsd_key}.3")
        expect(Rails.logger)
          .to receive(:info)
          .with("IVC ChampVA Forms - #{form_number} Current User LOA", current_user_loa: 3)

        vha107959c.track_current_user_loa(mock_user)
      end
    end

    context 'when current loa is missing' do
      it 'increments the StatsD for user loa 0 and logs the info' do
        mock_user = double(loa: double)
        allow(mock_user.loa).to receive(:[]).with(:current).and_return(nil)

        expect(StatsD).to receive(:increment).with("#{statsd_key}.0")
        expect(Rails.logger)
          .to receive(:info)
          .with("IVC ChampVA Forms - #{form_number} Current User LOA", current_user_loa: 0)

        vha107959c.track_current_user_loa(mock_user)
      end
    end
  end

  describe '#track_email_usage' do
    context 'when email is used' do
      let(:data) { { 'primary_contact_info' => { 'email' => 'test@example.com' } } }

      it 'increments the StatsD for email used and logs the info' do
        expect(StatsD).to receive(:increment).with("#{statsd_key}.yes")
        expect(Rails.logger).to receive(:info).with("IVC ChampVA Forms - #{form_number} Email Used",
                                                    email_used: 'yes')

        vha107959c.track_email_usage
      end
    end

    context 'when email is not used' do
      let(:data) { { 'primary_contact_info' => {} } }

      it 'increments the StatsD for email not used and logs the info' do
        expect(StatsD).to receive(:increment).with("#{statsd_key}.no")
        expect(Rails.logger).to receive(:info).with("IVC ChampVA Forms - #{form_number} Email Used", email_used: 'no')

        vha107959c.track_email_usage
      end
    end
  end

  describe '#track_delegate_form' do
    it 'increments the StatsD for delegate form and logs the info' do
      expect(StatsD).to receive(:increment).with("#{statsd_key}.delegate_form.vha_10_10d")
      expect(Rails.logger)
        .to receive(:info)
        .with("IVC ChampVA Forms - #{form_number} Delegate Form", parent_form_id: 'vha_10_10d')

      vha107959c.track_delegate_form('vha_10_10d')
    end
  end

  describe '#method_missing' do
    it 'returns the method name and arguments' do
      result = vha107959c.some_missing_method('arg1', 'arg2')

      expect(result).to eq({ method: :some_missing_method, args: %w[arg1 arg2] })
    end
  end

  describe '#handle_attachments' do
    let(:file_name) { "#{uuid}_vha_#{form_number.gsub('-', '_').downcase}-tmp.pdf" }

    it 'renames the file and returns the new file path' do
      allow(File).to receive(:rename)
      result = vha107959c.handle_attachments(file_name)

      expect(result).to eq([file_name])
    end
  end

  it 'is not past OMB expiration date' do
    # Update this date string to match the current PDF OMB expiration date:
    omb_expiration_date = Date.strptime('12312027', '%m%d%Y')
    error_message = <<~MSG
      If this test is failing it likely means the form #{form_number} PDF has reached
      OMB expiration date. Please see ivc_champva module README for details on updating the PDF file.
    MSG

    expect(omb_expiration_date.past?).to be(false), error_message
  end
end
