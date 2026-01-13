# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::VHA1010d2027 do
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
        'email' => 'john.doe@example.com',
        'va_claim_number' => '123456789',
        'address' => { 'country' => 'USA', 'postal_code' => '12345' }
      },
      'form_number' => 'VHA1010d2027',
      'has_applicant_over65' => false,
      'veteran_supporting_documents' => [
        { 'confirmation_code' => 'abc123' },
        { 'confirmation_code' => 'def456' }
      ]
    }
  end
  let(:vha1010d2027) { described_class.new(data) }
  let(:logger) { instance_spy(Logger) }

  before { allow(Rails.logger).to receive(:info) }

  describe '#track_user_identity' do
    it 'returns the right data' do
      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json')
      data = JSON.parse(fixture_path.read)

      described_class.new(data).track_user_identity

      expect(Rails.logger).to have_received(:info)
        .with('IVC ChampVA Forms - 10-10D-2027 Submission User Identity', { identity: 'applicant' })
    end
  end

  describe '#metadata' do
    it 'returns metadata for the form' do
      metadata = vha1010d2027.metadata

      expect(metadata).to include(
        'veteranFirstName' => 'John',
        'veteranLastName' => 'Doe',
        'veteranEmail' => 'john.doe@example.com',
        'fileNumber' => '123456789',
        'zipCode' => '12345',
        'country' => 'USA',
        'source' => 'VA Platform Digital Forms',
        'docType' => 'VHA1010d2027',
        'businessLine' => 'CMP',
        'hasApplicantOver65' => 'false',
        'primaryContactInfo' => {
          'name' => {
            'first' => 'Veteran',
            'last' => 'Surname'
          },
          'email' => false
        },
        'primaryContactEmail' => 'false',
        'formExpiration' => '12/31/2027'
      )
    end

    context 'when veteran email is not provided' do
      let(:data_without_email) do
        data_copy = data.dup
        data_copy['veteran'] = data_copy['veteran'].except('email')
        data_copy
      end
      let(:vha1010d2027_no_email) { described_class.new(data_without_email) }

      it 'returns nil for veteranEmail' do
        metadata = vha1010d2027_no_email.metadata
        expect(metadata['veteranEmail']).to be_nil
      end
    end

    context 'when using fixture data with veteran email' do
      let(:fixture_data) do
        fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json')
        JSON.parse(fixture_path.read)
      end
      let(:vha1010d2027_from_fixture) { described_class.new(fixture_data) }

      it 'extracts veteran email from fixture data correctly' do
        metadata = vha1010d2027_from_fixture.metadata
        expect(metadata['veteranEmail']).to eq('veteran@example.com')
      end
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
      let(:vha1010d2027_with_deceased_sponsor) { described_class.new(data_with_deceased_sponsor) }

      it 'returns correct stamps including the first applicant country' do
        expect(vha1010d2027_with_deceased_sponsor.desired_stamps).to include(
          hash_including(coords: [520, 470], text: 'Canada', page: 0)
        )
      end
    end

    context 'when sponsor is not deceased' do
      it 'returns correct stamps including veteran country and the first applicant country' do
        expect(vha1010d2027.desired_stamps).to include(
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
      let(:vha1010d2027_with_multiple_applicants) { described_class.new(data_with_multiple_applicants) }

      it 'returns stamps for all applicants' do
        stamps = vha1010d2027_with_multiple_applicants.desired_stamps
        expect(stamps.count { |stamp| %w[Canada Mexico].include?(stamp[:text]) }).to eq(2)
        expect(stamps).to include(
          hash_including(coords: [520, 470], text: 'Canada', page: 0),
          hash_including(coords: [520, 354], text: 'Mexico', page: 0)
        )
      end
    end
  end

  describe '#track_email_usage' do
    let(:statsd_key) { 'api.ivc_champva_form.10_10d' }
    let(:form_instance) { described_class.new(data) }

    context 'when email is used' do
      let(:data) { { 'primary_contact_info' => { 'email' => 'test@example.com' } } }

      it 'increments the StatsD for email used and logs the info' do
        expect(StatsD).to receive(:increment).with("#{statsd_key}.yes")
        expect(Rails.logger).to receive(:info).with('IVC ChampVA Forms - 10-10D-2027 Email Used', email_used: 'yes')
        form_instance.track_email_usage
      end
    end

    context 'when email is not used' do
      let(:data) { { 'primary_contact_info' => {} } }

      it 'increments the StatsD for email not used and logs the info' do
        expect(StatsD).to receive(:increment).with("#{statsd_key}.no")
        expect(Rails.logger).to receive(:info).with('IVC ChampVA Forms - 10-10D-2027 Email Used', email_used: 'no')
        form_instance.track_email_usage
      end
    end
  end

  describe '#track_submission' do
    let(:statsd_key) { 'api.ivc_champva_form.10_10d' }
    let(:form_version) { 'vha_10_10d_2027' }
    let(:mock_user) { double(loa: { current: 3 }) }

    context 'with standard form flow' do
      let(:submission_data) do
        {
          'certifier_role' => 'applicant',
          'primary_contact_info' => { 'email' => 'test@example.com' },
          'form_number' => '10-10D'
        }
      end
      let(:form_instance) { described_class.new(submission_data) }

      it 'increments StatsD with tags and logs submission info' do
        expect(StatsD).to receive(:increment).with(
          "#{statsd_key}.submission",
          tags: %w[identity:applicant current_user_loa:3 email_used:yes form_version:vha_10_10d_2027]
        )
        expect(Rails.logger).to receive(:info).with(
          'IVC ChampVA Forms - 10-10D-2027 Submission',
          identity: 'applicant',
          current_user_loa: 3,
          email_used: 'yes',
          form_version:
        )

        form_instance.track_submission(mock_user)
      end
    end

    context 'when current_user is nil' do
      let(:submission_data) do
        {
          'certifier_role' => 'applicant',
          'primary_contact_info' => {},
          'form_number' => '10-10D'
        }
      end
      let(:form_instance) { described_class.new(submission_data) }

      it 'defaults loa to 0' do
        expect(StatsD).to receive(:increment).with(
          "#{statsd_key}.submission",
          tags: %w[identity:applicant current_user_loa:0 email_used:no form_version:vha_10_10d_2027]
        )
        expect(Rails.logger).to receive(:info).with(
          'IVC ChampVA Forms - 10-10D-2027 Submission',
          identity: 'applicant',
          current_user_loa: 0,
          email_used: 'no',
          form_version:
        )

        form_instance.track_submission(nil)
      end
    end
  end

  [{
    flipper_enabled: false,
    applicant_key: 'applicant'
  }, {
    flipper_enabled: true,
    applicant_key: 'beneficiary'
  }].each do |test_case|
    describe '#add_applicant_properties' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_update_metadata_keys).and_return(test_case[:flipper_enabled])
      end

      context 'when applicants array is present' do
        let(:applicant_data) do
          data.merge(
            'applicants' => [
              { 'applicant_ssn' => '123456789', 'applicant_name' => { 'first' => 'John', 'last' => 'Doe' },
                'applicant_dob' => '1980-01-01' },
              { 'applicant_ssn' => '987654321', 'applicant_name' => { 'first' => 'Jane', 'last' => 'Doe' },
                'applicant_dob' => '1981-02-02' }
            ]
          )
        end

        let(:vha1010d2027_applicants) { described_class.new(applicant_data) }

        it 'returns valid stringified JSON' do
          res = vha1010d2027_applicants.add_applicant_properties
          expect(res["#{test_case[:applicant_key]}_0"]).to be_a(String)
          expect(JSON.parse(res["#{test_case[:applicant_key]}_0"])).to be_a(Hash)
        end

        it 'includes a key for each applicant' do
          res = vha1010d2027_applicants.add_applicant_properties
          expect(res.keys.include?("#{test_case[:applicant_key]}_0")).to be(true)
          expect(res.keys.include?("#{test_case[:applicant_key]}_1")).to be(true)
        end

        it 'contains applicant data' do
          res = vha1010d2027_applicants.add_applicant_properties
          first_name = JSON.parse(res["#{test_case[:applicant_key]}_0"])["#{test_case[:applicant_key]}_name"]['first']
          expect(first_name).to eq('John')
        end
      end

      context 'when applicants array is empty' do
        let(:applicant_data) do
          data.merge(
            'applicants' => []
          )
        end

        let(:vha1010d2027_applicants) { described_class.new(applicant_data) }

        it 'returns an empty object' do
          json_result = vha1010d2027.add_applicant_properties
          expect(json_result.empty?).to be(true)
        end
      end

      context 'when applicants have wrong properties' do
        let(:applicant_data) do
          data.merge(
            'applicants' => [
              { 'applicant_ssn' => '123456789', 'applicant_name' => { 'first' => 'John', 'last' => 'Doe' },
                'applicant_dob' => '1980-01-01' }
            ]
          )
        end

        let(:vha1010d2027_applicants) { described_class.new(applicant_data) }

        it 'returns an empty object' do
          json_result = vha1010d2027.add_applicant_properties
          expect(json_result.empty?).to be(true)
        end

        it 'does not interfere with metadata creation' do
          expect(vha1010d2027.metadata.keys.include?('veteranFirstName')).to be(true)
        end
      end
    end
  end

  describe 'veteran email field mapping' do
    context 'when veteran email is provided in the expected format' do
      let(:email_data) do
        {
          'veteran' => {
            'full_name' => { 'first' => 'Test', 'last' => 'User' },
            'email' => 'test.user@example.com'
          },
          'form_number' => 'VHA1010d2027'
        }
      end
      let(:vha1010d2027_with_email) { described_class.new(email_data) }

      it 'correctly maps veteran email to metadata' do
        metadata = vha1010d2027_with_email.metadata
        expect(metadata['veteranEmail']).to eq('test.user@example.com')
      end
    end

    context 'when veteran email contains special characters' do
      let(:special_email_data) do
        {
          'veteran' => {
            'full_name' => { 'first' => 'Test', 'last' => 'User' },
            'email' => 'test.user+tag@example.com'
          },
          'form_number' => 'VHA1010d2027'
        }
      end
      let(:vha1010d2027_special_email) { described_class.new(special_email_data) }

      it 'preserves email with special characters' do
        metadata = vha1010d2027_special_email.metadata
        expect(metadata['veteranEmail']).to eq('test.user+tag@example.com')
      end
    end
  end

  it 'is not past OMB expiration date' do
    # Update this date string to match the current PDF OMB expiration date:
    omb_expiration_date = Date.strptime('12312027', '%m%d%Y')
    error_message = <<~MSG
      If this test is failing it likely means the form 10-10d-2027 PDF has reached
      OMB expiration date. Please see ivc_champva module README for details on updating the PDF file.
    MSG

    expect(omb_expiration_date.past?).to be(false), error_message
  end
end
