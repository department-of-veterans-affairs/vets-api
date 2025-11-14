# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::VHA107959a do
  let(:current_user) { build(:user, :loa3) }

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
    context 'when champva_update_metadata_keys flipper is enabled' do
      it 'returns metadata for the form' do
        allow(Flipper).to receive(:enabled?).with(:champva_update_metadata_keys).and_return(true)
        metadata = vha_10_7959a.metadata

        expect(metadata).to include(
          'sponsorFirstName' => 'John',
          'sponsorLastName' => 'Doe',
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

    context 'when champva_update_metadata_keys flipper is disabled' do
      it 'returns metadata for the form' do
        allow(Flipper).to receive(:enabled?).with(:champva_update_metadata_keys).and_return(false)
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
  end

  describe '#add_resubmission_properties' do
    context 'when medical claim resubmission data is present' do
      let(:medical_resubmission_data) do
        # update data to reflect a resubmitted medical claim
        data.merge(
          {
            'claim_status' => 'resubmission',
            'pdi_or_claim_number' => 'PDI number',
            'identifying_number' => 'va12345678',
            'claim_type' => 'medical',
            'provider_name' => 'BCBS',
            'beginning_date_of_service' => '01-01-1999',
            'end_date_of_service' => '01-02-1999'
          }
        )
      end

      let(:vha107959a_medical_resubmission) { described_class.new(medical_resubmission_data) }

      it 'includes a key for each present resubmission property' do
        res = vha107959a_medical_resubmission.add_resubmission_properties
        expect(res.keys.include?('claim_status')).to be(true)
        expect(res.keys.include?('pdi_or_claim_number')).to be(true)
        expect(res.keys.include?('claim_type')).to be(true)
        expect(res.keys.include?('provider_name')).to be(true)
        expect(res.keys.include?('beginning_date_of_service')).to be(true)
        expect(res.keys.include?('end_date_of_service')).to be(true)
        expect(res.keys.include?('pdi_number')).to be(true)
      end

      it 'contains resubmission data' do
        res = vha107959a_medical_resubmission.add_resubmission_properties
        expect(res['claim_status']).to eq('resubmission')
      end

      it 'includes relevant pdi field and excludes claim number field when pdi number was specified' do
        res = vha107959a_medical_resubmission.add_resubmission_properties
        expect(res.keys.include?('pdi_number')).to be(true)
        expect(res.keys.include?('claim_number')).to be(false)
      end
    end

    context 'when resubmission properties are missing' do
      context 'when champva_update_metadata_keys flipper is enabled' do
        it 'does not interfere with metadata creation' do
          allow(Flipper).to receive(:enabled?).with(:champva_update_metadata_keys).and_return(true)

          expect(vha_10_7959a.metadata.keys.include?('sponsorFirstName')).to be(true)
        end
      end

      context 'when champva_update_metadata_keys flipper is disabled' do
        it 'does not interfere with metadata creation' do
          allow(Flipper).to receive(:enabled?).with(:champva_update_metadata_keys).and_return(false)

          expect(vha_10_7959a.metadata.keys.include?('veteranFirstName')).to be(true)
        end
      end

      it 'does not include resubmission property if there is no corresponding value' do
        # vha_10_7959a was initialized with no resubmission values
        res = vha_10_7959a.add_resubmission_properties
        # this key will not be present even though `add_resubmission_properties` attempts to get it from the form data
        expect(res.keys.include?('claim_status')).to be(false)
      end
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

  describe '#track_current_user_loa' do
    it 'logs current user loa' do
      expect(Rails.logger).to receive(:info)
        .with('IVC ChampVA Forms - 10-7959A Current User LOA', { current_user_loa: 3 })
      vha_10_7959a.track_current_user_loa(current_user)
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
