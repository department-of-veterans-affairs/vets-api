# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::AutoEstablishedClaim, type: :model do
  let(:auto_form) { build(:auto_established_claim, auth_headers: { some: 'data' }) }
  let(:pending_record) { create(:auto_established_claim) }

  describe 'encrypted attributes' do
    it 'does the thing' do
      expect(subject).to encrypt_attr(:form_data)
      expect(subject).to encrypt_attr(:auth_headers)
      expect(subject).to encrypt_attr(:file_data)
    end
  end

  it 'writes flashes and special issues to log on create' do
    expect(Rails.logger).to receive(:info)
      .with(/ClaimsApi: Claim\[.+\] contains the following flashes - \["Hardship", "Homeless"\]/)
    expect(Rails.logger).to receive(:info)
      .with(%r{ClaimsApi: Claim\[.+\] contains the following special issues - \[.*FDC.*PTSD/2.*\]})
    pending_record
  end

  describe 'validate_service_dates' do
    context 'when activeDutyEndDate is before activeDutyBeginDate' do
      it 'throws an error' do
        auto_form.form_data = { 'serviceInformation' => { 'servicePeriods' => [{
          'activeDutyBeginDate' => '1991-05-02',
          'activeDutyEndDate' => '1990-04-05'
        }] } }

        expect(auto_form.save).to eq(false)
        expect(auto_form.errors.messages).to include(:activeDutyBeginDate)
      end
    end

    context 'when activeDutyEndDate is not provided' do
      it 'throws an error' do
        auto_form.form_data = { 'serviceInformation' => { 'servicePeriods' => [{
          'activeDutyBeginDate' => '1991-05-02',
          'activeDutyEndDate' => nil
        }] } }

        expect(auto_form.save).to eq(true)
      end
    end

    context 'when activeDutyBeginDate is not provided' do
      it 'throws an error' do
        auto_form.form_data = { 'serviceInformation' => { 'servicePeriods' => [{
          'activeDutyBeginDate' => nil,
          'activeDutyEndDate' => '1990-04-05'
        }] } }

        expect(auto_form.save).to eq(false)
        expect(auto_form.errors.messages).to include(:activeDutyBeginDate)
      end
    end
  end

  describe 'pending?' do
    context 'no pending records' do
      it 'is false' do
        expect(described_class.pending?('123')).to be(false)
      end
    end

    context 'with pending records' do
      it 'truthies and return the record' do
        result = described_class.pending?(pending_record.id)
        expect(result).to be_truthy
        expect(result.id).to eq(pending_record.id)
      end
    end
  end

  describe 'translate form_data' do
    it 'checks an active claim date' do
      payload = JSON.parse(pending_record.to_internal)
      expect(payload['form526']['claimDate']).to eq('1990-01-03')
    end

    it 'adds an active claim date' do
      pending_record.form_data.delete('claimDate')
      payload = JSON.parse(pending_record.to_internal)
      expect(payload['form526']['claimDate']).to eq(pending_record.created_at.to_date.to_s)
    end

    it 'adds an identifier for Lighthouse submissions' do
      payload = JSON.parse(pending_record.to_internal)
      expect(payload['form526']['claimSubmissionSource']).to eq('Lighthouse')
    end

    it 'converts special issues to EVSS codes' do
      payload = JSON.parse(pending_record.to_internal)
      expect(payload['form526']['disabilities'].first['specialIssues']).to eq(['PTSD_2'])
      expect(payload['form526']['disabilities'].first['secondaryDisabilities'].first['specialIssues']).to eq([])
    end

    it 'converts homelessness situation type to EVSS code' do
      payload = JSON.parse(pending_record.to_internal)
      actual = payload['form526']['veteran']['homelessness']['currentlyHomeless']['homelessSituationType']
      expect(actual).to eq('FLEEING_CURRENT_RESIDENCE')
    end

    describe 'when days until release is between 90 and 180 days' do
      it 'sets bddQualified to true' do
        temp_form_data = pending_record.form_data
        temp_form_data['serviceInformation'] = {
          'servicePeriods' => [
            {
              'serviceBranch' => 'Air Force',
              'activeDutyBeginDate' => '1991-05-02',
              'activeDutyEndDate' => (Time.zone.now.to_date + 100.days).to_s
            }
          ]
        }
        pending_record.form_data = temp_form_data

        payload = JSON.parse(pending_record.to_internal)
        expect(payload['form526']['bddQualified']).to eq(true)
      end
    end

    describe 'when days until release is less than 90 days' do
      it 'sets bddQualified to false' do
        temp_form_data = pending_record.form_data
        temp_form_data['serviceInformation'] = {
          'servicePeriods' => [
            {
              'serviceBranch' => 'Air Force',
              'activeDutyBeginDate' => '1991-05-02',
              'activeDutyEndDate' => (Time.zone.now.to_date + 80.days).to_s
            }
          ]
        }
        pending_record.form_data = temp_form_data

        payload = JSON.parse(pending_record.to_internal)
        expect(payload['form526']['bddQualified']).to eq(false)
      end
    end

    describe 'when days until release is greater than 180 days' do
      describe 'when Veteran has previous service period' do
        it 'sets bddQualified to false' do
          temp_form_data = pending_record.form_data
          temp_form_data['serviceInformation'] = {
            'servicePeriods' => [
              {
                'serviceBranch' => 'Air Force',
                'activeDutyBeginDate' => '1991-05-02',
                'activeDutyEndDate' => (Time.zone.now.to_date + 190.days).to_s
              },
              {
                'serviceBranch' => 'Army',
                'activeDutyBeginDate' => '1991-05-02',
                'activeDutyEndDate' => (Time.zone.now.to_date - 1.day).to_s
              }
            ]
          }
          pending_record.form_data = temp_form_data

          payload = JSON.parse(pending_record.to_internal)
          expect(payload['form526']['bddQualified']).to eq(false)
        end
      end

      describe 'when Veteran does not have previous service period' do
        it 'raises an exception' do
          temp_form_data = pending_record.form_data
          temp_form_data['serviceInformation'] = {
            'servicePeriods' => [
              {
                'serviceBranch' => 'Air Force',
                'activeDutyBeginDate' => '1991-05-02',
                'activeDutyEndDate' => (Time.zone.now.to_date + 190.days).to_s
              }
            ]
          }
          pending_record.form_data = temp_form_data

          expect { pending_record.to_internal }.to raise_error(::Common::Exceptions::UnprocessableEntity)
        end
      end
    end

    describe "breaking out 'separationPay.receivedDate'" do
      it 'breaks it out by year, month, day' do
        temp_form_data = pending_record.form_data
        temp_form_data.merge!(
          {
            'servicePay' => {
              'separationPay' => {
                'received' => true,
                'receivedDate' => '2018-03-02',
                'payment' => {
                  'serviceBranch' => 'Air Force',
                  'amount' => 100
                }
              }
            }
          }
        )
        pending_record.form_data = temp_form_data

        payload = JSON.parse(pending_record.to_internal)
        expect(payload['form526']['servicePay']['separationPay']['receivedDate']).to include(
          'year' => '2018',
          'month' => '3',
          'day' => '2'
        )
      end
    end
  end

  describe 'evss_id_by_token' do
    context 'with a record' do
      let(:evss_record) { create(:auto_established_claim, evss_id: 123_456) }

      it 'returns the evss id of that record' do
        expect(described_class.evss_id_by_token(evss_record.token)).to eq(123_456)
      end
    end

    context 'with no record' do
      it 'returns nil' do
        expect(described_class.evss_id_by_token('thisisntatoken')).to be(nil)
      end
    end

    context 'with record without evss id' do
      it 'returns nil' do
        expect(described_class.evss_id_by_token(pending_record.token)).to be(nil)
      end
    end
  end

  context 'finding by ID or EVSS ID' do
    let(:evss_record) { create(:auto_established_claim, evss_id: 123_456) }

    before do
      evss_record
    end

    it 'finds by model id' do
      expect(described_class.get_by_id_or_evss_id(evss_record.id).id).to eq(evss_record.id)
    end

    it 'finds by evss id' do
      expect(described_class.get_by_id_or_evss_id(123_456).id).to eq(evss_record.id)
    end
  end

  describe '#set_file_data!' do
    it 'stores the file_data and give me a full evss document' do
      file = Rack::Test::UploadedFile.new(
        "#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf"
      )

      auto_form.set_file_data!(file, 'docType')
      auto_form.save!
      auto_form.reload

      expect(auto_form.file_data).to have_key('filename')
      expect(auto_form.file_data).to have_key('doc_type')

      expect(auto_form.file_name).to eq(auto_form.file_data['filename'])
      expect(auto_form.document_type).to eq(auto_form.file_data['doc_type'])
    end
  end
end
