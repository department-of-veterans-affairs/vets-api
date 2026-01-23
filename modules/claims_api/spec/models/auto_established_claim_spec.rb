# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::AutoEstablishedClaim, type: :model do
  let(:auto_form) { create(:auto_established_claim_va_gov, auth_headers: { some: 'data' }) }.freeze
  let(:pending_record) { create(:auto_established_claim, :special_issues, :flashes) }.freeze

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

  it 'writes flashes and special issues to the DB on create' do
    pending_claim = ClaimsApi::AutoEstablishedClaim.find(pending_record.id)
    va_gov_claim = ClaimsApi::AutoEstablishedClaim.find(auto_form.id)

    expect(pending_claim.form_data['disabilities'][0]['specialIssues']).to eq(['Fully Developed Claim', 'PTSD/2'])
    expect(pending_claim.flashes).to eq(%w[Hardship Homeless])
    expect(va_gov_claim.form_data['disabilities'][0]['specialIssues']).to eq([])
  end

  describe "persisting 'cid' (OKTA client_id)" do
    it "stores 'cid' in the DB upon creation" do
      expect(auto_form.cid).to eq('0oagdm49ygCSJTp8X297')
    end
  end

  describe '#set_header_hash' do
    it 'creates the header_hash and finds the claim' do
      expect(pending_record.header_hash).not_to be_nil
      pending_record.save
      saved_claim = ClaimsApi::AutoEstablishedClaim.find_by(header_hash: pending_record.header_hash)
      expect(saved_claim.header_hash).to eq(pending_record.header_hash)
    end
  end

  describe 'validate_service_dates' do
    context 'when activeDutyEndDate is before activeDutyBeginDate' do
      it 'throws an error' do
        auto_form.form_data = { 'serviceInformation' => { 'servicePeriods' => [{
          'activeDutyBeginDate' => '1991-05-02',
          'activeDutyEndDate' => '1990-04-05'
        }] } }

        expect(auto_form.save).to be(false)
        expect(auto_form.errors.messages).to include(:activeDutyBeginDate)
      end
    end

    context 'when activeDutyEndDate is not provided' do
      it 'throws an error' do
        auto_form.form_data = { 'serviceInformation' => { 'servicePeriods' => [{
          'activeDutyBeginDate' => '1991-05-02',
          'activeDutyEndDate' => nil
        }] } }

        expect(auto_form.save).to be(true)
      end
    end

    context 'when activeDutyBeginDate is not provided' do
      it 'throws an error' do
        auto_form.form_data = { 'serviceInformation' => { 'servicePeriods' => [{
          'activeDutyBeginDate' => nil,
          'activeDutyEndDate' => '1990-04-05'
        }] } }

        expect(auto_form.save).to be(false)
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
      expect(payload['form526']['claimDate']).to eq('1990-01-03T00:00:00+00:00')
    end

    it 'adds an active claim date' do
      pending_record.form_data.delete('claimDate')
      payload = JSON.parse(pending_record.to_internal)
      expect(payload['form526']['claimDate']).to eq(DateTime.parse(pending_record.created_at.iso8601).iso8601)
    end

    it 'converts a claim date to UTC' do
      pending_record.form_data['claimDate'] = '1990-01-03'
      payload = JSON.parse(pending_record.to_internal)
      expect(payload['form526']['claimDate']).to eq('1990-01-03T00:00:00+00:00')
    end

    it 'adds an identifier for Lighthouse submissions' do
      payload = JSON.parse(pending_record.to_internal)
      expect(payload['form526']['claimSubmissionSource']).to eq('LH-B')
    end

    it 'converts special issues to EVSS codes' do
      payload = JSON.parse(pending_record.to_internal)
      expect(payload['form526']['disabilities'].first['specialIssues']).to eq(['PTSD_2'])
    end

    it 'converts homelessness situation type to EVSS code' do
      payload = JSON.parse(pending_record.to_internal)
      actual = payload['form526']['veteran']['homelessness']['currentlyHomeless']['homelessSituationType']
      expect(actual).to eq('FLEEING_CURRENT_RESIDENCE')
    end

    it 'converts homelessness risk situation type to EVSS code' do
      temp_form_data = pending_record.form_data
      temp_form_data['veteran']['homelessness'].delete('currentlyHomeless')
      temp_form_data['veteran']['homelessness']['homelessnessRisk'] = {
        'homelessnessRiskSituationType' => 'losingHousing',
        'otherLivingSituation' => 'something'
      }
      pending_record.form_data = temp_form_data
      payload = JSON.parse(pending_record.to_internal)
      actual = payload['form526']['veteran']['homelessness']['homelessnessRisk']['homelessnessRiskSituationType']
      expect(actual).to eq('HOUSING_WILL_BE_LOST_IN_30_DAYS')
    end

    it 'removes a blank veteran.changeOfAddress.zipLastFour' do
      change_of_address = {
        'beginningDate' => 1.month.from_now.to_date.to_s,
        'endingDate' => 6.months.from_now.to_date.to_s,
        'addressChangeType' => 'TEMPORARY',
        'addressLine1' => '1234 Couch Street',
        'city' => 'New York City',
        'state' => 'NY',
        'type' => 'DOMESTIC',
        'zipFirstFive' => '12345',
        'zipLastFour' => '',
        'country' => 'USA'
      }

      pending_record.form_data['veteran']['changeOfAddress'] = change_of_address
      payload = JSON.parse(pending_record.to_internal)
      expect(payload['form526']['veteran']['changeOfAddress']).not_to have_key('zipLastFour')
    end

    context 'when homelessness risk situation type is "other" and "otherLivingSituation" is not provided' do
      it 'does not add "otherLivingSituation" to pass EVSS validation' do
        temp_form_data = pending_record.form_data
        temp_form_data['veteran']['homelessness'].delete('currentlyHomeless')
        temp_form_data['veteran']['homelessness']['homelessnessRisk'] = {
          'homelessnessRiskSituationType' => 'other'
        }
        pending_record.form_data = temp_form_data
        payload = JSON.parse(pending_record.to_internal)
        homelessness_risk = payload['form526']['veteran']['homelessness']['homelessnessRisk']
        expect(homelessness_risk['homelessnessRiskSituationType']).to eq('OTHER')
        expect(homelessness_risk).not_to have_key('otherLivingSituation')
      end
    end

    context 'when homelessness risk situation type is "other" and "otherLivingSituation" is an empty string' do
      it 'removes "otherLivingSituation" to pass EVSS validations' do
        temp_form_data = pending_record.form_data
        temp_form_data['veteran']['homelessness'].delete('currentlyHomeless')
        temp_form_data['veteran']['homelessness']['homelessnessRisk'] = {
          'homelessnessRiskSituationType' => 'other',
          'otherLivingSituation' => ''
        }
        pending_record.form_data = temp_form_data
        payload = JSON.parse(pending_record.to_internal)
        homelessness_risk = payload['form526']['veteran']['homelessness']['homelessnessRisk']
        expect(homelessness_risk['homelessnessRiskSituationType']).to eq('OTHER')
        expect(homelessness_risk).not_to have_key('otherLivingSituation')
      end
    end

    it 'is case insensitive when the homelessnessRiskSituationType is "OTHER"' do
      temp_form_data = pending_record.form_data
      temp_form_data['veteran']['homelessness'].delete('currentlyHomeless')
      temp_form_data['veteran']['homelessness']['homelessnessRisk'] = {
        'homelessnessRiskSituationType' => 'OTHER'
      }
      pending_record.form_data = temp_form_data
      payload = JSON.parse(pending_record.to_internal)
      homelessness_risk = payload['form526']['veteran']['homelessness']['homelessnessRisk']
      expect(homelessness_risk['homelessnessRiskSituationType']).to eq('OTHER')
      expect(homelessness_risk).not_to have_key('otherLivingSituation')
    end

    it 'is case insensitive when the homelessSituationType is "OTHER"' do
      temp_form_data = pending_record.form_data
      temp_form_data['veteran']['homelessness']['currentlyHomeless']['homelessSituationType'] = 'OTHER'

      pending_record.form_data = temp_form_data
      payload = JSON.parse(pending_record.to_internal)
      currently_homeless = payload['form526']['veteran']['homelessness']['currentlyHomeless']

      expect(currently_homeless['homelessSituationType']).to eq('OTHER')
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
                  'serviceBranch' => 'National Oceanic and Atmospheric Administration',
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

    describe 'handles &amp in service branch for separation pay' do
      it 'and retrieves payment' do
        temp_form_data = pending_record.form_data
        temp_form_data.merge!(
          {
            'servicePay' => {
              'separationPay' => {
                'received' => true,
                'receivedDate' => '2022-03-02',
                'payment' => {
                  'serviceBranch' => 'National Oceanic &amp; Atmospheric Administration',
                  'amount' => 150
                }
              }
            }
          }
        )
        pending_record.form_data = temp_form_data

        payload = JSON.parse(pending_record.to_internal)
        expect(payload['form526']['servicePay']['separationPay']['payment']['serviceBranch']).to include(
          'National Oceanic & Atmospheric Administration'
        )
      end
    end

    describe 'handles &amp in service branch for militaryRetiredPay' do
      it 'and retrieves payment' do
        temp_form_data = pending_record.form_data
        temp_form_data.merge!(
          {
            'servicePay' => {
              'militaryRetiredPay' => {
                'received' => true,
                'receivedDate' => '2022-03-02',
                'payment' => {
                  'serviceBranch' => 'National Oceanic &amp; Atmospheric Administration',
                  'amount' => 150
                }
              }
            }
          }
        )
        pending_record.form_data = temp_form_data

        payload = JSON.parse(pending_record.to_internal)
        expect(payload['form526']['servicePay']['militaryRetiredPay']['payment']['serviceBranch']).to include(
          'National Oceanic & Atmospheric Administration'
        )
      end
    end

    describe 'handles & in service branch for militaryRetiredPay' do
      it 'and retrieves payment' do
        temp_form_data = pending_record.form_data
        temp_form_data.merge!(
          {
            'servicePay' => {
              'militaryRetiredPay' => {
                'received' => true,
                'receivedDate' => '2022-03-02',
                'payment' => {
                  'serviceBranch' => 'National Oceanic & Atmospheric Administration',
                  'amount' => 150
                }
              }
            }
          }
        )
        pending_record.form_data = temp_form_data

        payload = JSON.parse(pending_record.to_internal)
        expect(payload['form526']['servicePay']['militaryRetiredPay']['payment']['serviceBranch']).to include(
          'National Oceanic & Atmospheric Administration'
        )
      end
    end

    describe "breaking out 'disabilities.approximateBeginDate'" do
      it 'breaks it out by year, month, day' do
        disability = pending_record.form_data['disabilities'].first
        disability.merge!(
          {
            'approximateBeginDate' => '1989-12-01'
          }
        )
        pending_record.form_data['disabilities'][0] = disability

        payload = JSON.parse(pending_record.to_internal)
        expect(payload['form526']['disabilities'].first['approximateBeginDate']).to include(
          'year' => '1989',
          'month' => '12',
          'day' => '1'
        )
      end
    end

    describe "handling 'changeOfAddress.endingDate'" do
      context "when 'changeOfAddress' is provided" do
        let(:change_of_address) do
          {
            'beginningDate' => 1.month.from_now.to_date.to_s,
            'endingDate' => ending_date,
            'addressChangeType' => address_change_type,
            'addressLine1' => '1234 Couch Street',
            'city' => 'New York City',
            'state' => 'NY',
            'type' => 'DOMESTIC',
            'zipFirstFive' => '12345',
            'country' => 'USA'
          }
        end
        let(:ending_date) { 6.months.from_now.to_date.to_s }

        context "when 'changeOfAddress.addressChangeType' is 'TEMPORARY'" do
          let(:address_change_type) { 'TEMPORARY' }

          context "and 'changeOfAddress.endingDate' is not provided" do
            it "sets 'changeOfAddress.endingDate' to 1 year in the future" do
              change_of_address.delete('endingDate')
              pending_record.form_data['veteran']['changeOfAddress'] = change_of_address

              payload = JSON.parse(pending_record.to_internal)
              transformed_ending_date = payload['form526']['veteran']['changeOfAddress']['endingDate']

              expect(transformed_ending_date).to eq((Time.zone.now.to_date + 1.year).to_s)
            end
          end

          context "and 'changeOfAddress.endingDate' is provided" do
            it "does not change 'changeOfAddress.endingDate'" do
              pending_record.form_data['veteran']['changeOfAddress'] = change_of_address

              payload = JSON.parse(pending_record.to_internal)
              untouched_ending_date = payload['form526']['veteran']['changeOfAddress']['endingDate']

              expect(untouched_ending_date).to eq(ending_date)
            end
          end

          context "when 'changeOfAddress.addressChangeType' is not uppercased" do
            let(:address_change_type) { 'temporary' }

            it "transforms 'changeOfAddress.addressChangeType' to uppercase" do
              pending_record.form_data['veteran']['changeOfAddress'] = change_of_address
              original_value = pending_record.form_data['veteran']['changeOfAddress']['addressChangeType']
              expect(original_value).to eq('temporary')

              payload = JSON.parse(pending_record.to_internal)
              transformed_value = payload['form526']['veteran']['changeOfAddress']['addressChangeType']

              expect(transformed_value).to eq('TEMPORARY')
            end
          end
        end

        context "when 'changeOfAddress.addressChangeType' is 'PERMANENT'" do
          let(:address_change_type) { 'PERMANENT' }

          context "and 'changeOfAddress.endingDate' is provided" do
            let(:ending_date) { 6.months.from_now.to_date.to_s }

            it "removes the 'changeOfAddress.endingDate'" do
              pending_record.form_data['veteran']['changeOfAddress'] = change_of_address

              payload = JSON.parse(pending_record.to_internal)
              transformed_ending_date = payload['form526']['veteran']['changeOfAddress']['endingDate']

              expect(transformed_ending_date).to be_nil
            end
          end

          context "and 'changeOfAddress.endingDate' is not provided" do
            it "does not add a 'changeOfAddress.endingDate'" do
              change_of_address.delete('endingDate')
              pending_record.form_data['veteran']['changeOfAddress'] = change_of_address

              payload = JSON.parse(pending_record.to_internal)
              untouched_ending_date = payload['form526']['veteran']['changeOfAddress']['endingDate']

              expect(untouched_ending_date).to be_nil
            end
          end

          context "when 'changeOfAddress.addressChangeType' is not uppercased" do
            let(:address_change_type) { 'permanent' }

            it "transforms 'changeOfAddress.addressChangeType' to uppercase" do
              pending_record.form_data['veteran']['changeOfAddress'] = change_of_address
              original_value = pending_record.form_data['veteran']['changeOfAddress']['addressChangeType']
              expect(original_value).to eq('permanent')

              payload = JSON.parse(pending_record.to_internal)
              transformed_value = payload['form526']['veteran']['changeOfAddress']['addressChangeType']

              expect(transformed_value).to eq('PERMANENT')
            end
          end
        end
      end
    end

    describe "scrubbing 'specialIssues' on 'secondaryDisabilities'" do
      context "when a 'secondaryDisability' has 'specialIssues'" do
        it "removes the 'specialIssues' attribute" do
          pending_record.form_data['disabilities'].first['secondaryDisabilities'].first['specialIssues'] = []
          pending_record.form_data['disabilities'].first['secondaryDisabilities'].first['specialIssues'] << 'ALS'

          payload = JSON.parse(pending_record.to_internal)
          special_issues = payload['form526']['disabilities'].first['secondaryDisabilities'].first['specialIssues']

          expect(special_issues).to be_nil
        end
      end

      context "when a 'secondaryDisability' does not have 'specialIssues'" do
        it 'does not change anything' do
          pre_processed_disabilities = pending_record.form_data['disabilities']
          payload = JSON.parse(pending_record.to_internal)
          post_processed_disabilities = payload['form526']['disabilities']

          expect(pre_processed_disabilities).to eql(post_processed_disabilities)
        end
      end

      context "when a 'secondaryDisability' does not exist" do
        it 'does not change anything' do
          pending_record.form_data['disabilities'].first.delete('secondaryDisabilities')

          pre_processed_disabilities = pending_record.form_data['disabilities']
          payload = JSON.parse(pending_record.to_internal)
          post_processed_disabilities = payload['form526']['disabilities']

          expect(pre_processed_disabilities).to eql(post_processed_disabilities)
        end
      end
    end

    it 'removes spaces' do
      temp_form_data = pending_record.form_data
      temp_form_data['disabilities'][0]['name'] = ' string with spaces '

      pending_record.form_data = temp_form_data
      payload = JSON.parse(pending_record.to_internal)
      name = payload['form526']['disabilities'][0]['name']

      expect(name).to eq('string with spaces')
    end

    it 'combines address lines' do
      temp_form_data = pending_record.form_data
      temp_form_data['veteran']['currentMailingAddress']['addressLine1'] = '1234 Long address line 1'
      temp_form_data['veteran']['currentMailingAddress']['addressLine2'] = 'Suite 1'
      temp_form_data['veteran']['currentMailingAddress']['addressLine3'] = 'Appt 5'

      pending_record.form_data = temp_form_data
      payload = JSON.parse(pending_record.to_internal)
      ln1 = payload['form526']['veteran']['currentMailingAddress']['addressLine1']
      ln2 = payload['form526']['veteran']['currentMailingAddress']['addressLine2']
      ln3 = payload['form526']['veteran']['currentMailingAddress']['addressLine3']

      expect(ln1).to eq('1234 Long address')
      expect(ln2).to eq('line 1')
      expect(ln3).to eq('Suite 1 Appt 5')
    end

    it "handles 'treatments[].center.name' as an empty string" do
      temp_form_data = pending_record.form_data
      temp_form_data['treatments'] = [
        {
          treatedDisabilityNames: ['PTSD (post traumatic stress disorder)'],
          center: {
            name: '',
            country: 'USA'
          }
        }
      ]

      pending_record.form_data = temp_form_data
      payload = JSON.parse(pending_record.to_internal)

      expect(payload['form526']['treatments'][0]['center']['name']).to eq(' ')
    end

    context 'handles empty spaces and dashes in the unitPhone numbers values' do
      let(:temp_form_data) do
        pending_record.form_data.tap do |data|
          data['serviceInformation']['reservesNationalGuardService']['unitPhone'] = {
            'areaCode' => '  555  ',
            'phoneNumber' => '555-5555  '
          }
        end
      end
      let(:payload) { JSON.parse(pending_record.to_internal) }
      let(:reserves) { payload['form526']['serviceInformation']['reservesNationalGuardService'] }

      before do
        pending_record.form_data = temp_form_data
      end

      it 'removes any extra spaces and dashes from the phoneNumber' do
        phone_number = reserves['unitPhone']['phoneNumber']
        expect(phone_number).to eq('5555555')
      end

      it 'removes any extra spaces from the areaCode' do
        phone_number = reserves['unitPhone']['areaCode']
        expect(phone_number).to eq('555')
      end
    end

    context 'when the unitPhone number has more than 10 digits' do
      let(:temp_form_data) do
        pending_record.form_data.tap do |data|
          data['serviceInformation']['reservesNationalGuardService']['unitPhone'] = {
            'areaCode' => '555',
            'phoneNumber' => '1231234x5555'
          }
        end
      end
      let(:payload) { JSON.parse(pending_record.to_internal) }
      let(:reserves) { payload['form526']['serviceInformation']['reservesNationalGuardService'] }

      before do
        pending_record.form_data = temp_form_data
      end

      it 'adds the original phone number to overflowText and removes unitPhone' do
        expect(payload['form526']['overflowText']).to eq("21E. unitPhone - 5551231234x5555\n")
        expect(reserves['unitPhone']).to be_nil
      end
    end

    context 'when both unitPhone and primaryPhone have more than 10 digits' do
      let(:temp_form_data) do
        pending_record.form_data.tap do |data|
          data['serviceInformation']['reservesNationalGuardService']['unitPhone'] = {
            'areaCode' => '555',
            'phoneNumber' => '1231234x5555'
          }
          data['veteran']['homelessness']['pointOfContact']['primaryPhone'] = {
            'areaCode' => '555',
            'phoneNumber' => '1231234x5555'
          }
        end
      end
      let(:payload) { JSON.parse(pending_record.to_internal) }
      let(:reserves) { payload['form526']['serviceInformation']['reservesNationalGuardService'] }
      let(:point_of_contact) { payload['form526']['veteran']['homelessness']['pointOfContact'] }

      before do
        pending_record.form_data = temp_form_data
      end

      it 'adds the original phone numbers to overflowText and removes unitPhone and primaryPhone' do
        expect(payload['form526']['overflowText'])
          .to eq("21E. unitPhone - 5551231234x5555\n14F. pointOfContact.primaryPhone - 5551231234x5555\n")
        expect(reserves['unitPhone']).to be_nil
        expect(point_of_contact['primaryPhone']).to be_nil
      end
    end

    context 'removes empty disabilities having only empty string name and disabilityActionType' do
      let(:temp_form_data) do
        pending_record.form_data.tap do |data|
          data['disabilities'] = [{
            'disabilityActionType' => 'NEW',
            'name' => ''
          }]
        end
      end
      let(:payload) { JSON.parse(pending_record.to_internal) }
      let(:disabilities) { payload['form526']['disabilities'] }

      before do
        pending_record.form_data = temp_form_data
      end

      it 'removes the disability' do
        expect(disabilities).to eq([])
      end
    end
  end

  describe '#transform_empty_unit_name!' do
    let(:unit_name) { '' }

    it 'trasforms an empty unit name to a space' do
      temp_form_data = pending_record.form_data
      temp_form_data['serviceInformation']['reservesNationalGuardService']['unitName'] = unit_name

      pending_record.form_data = temp_form_data
      payload = JSON.parse(pending_record.to_internal)
      name = payload['form526']['serviceInformation']['reservesNationalGuardService']['unitName']

      expect(name).to eq(' ')
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
        expect(described_class.evss_id_by_token('thisisntatoken')).to be_nil
      end
    end

    context 'with record without evss id' do
      it 'returns nil' do
        expect(described_class.evss_id_by_token(pending_record.token)).to be_nil
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
        Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
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

  describe "breaking out 'treatments.startDate'" do
    it 'breaks it out by year, month, day' do
      treatments = [
        {
          'center' => {
            'name' => 'Some Treatment Center',
            'country' => 'United States of America'
          },
          'treatedDisabilityNames' => [
            'PTSD (post traumatic stress disorder)'
          ],
          'startDate' => '1985-01-01'
        }
      ]

      pending_record.form_data['treatments'] = treatments

      payload = JSON.parse(pending_record.to_internal)
      expect(payload['form526']['treatments'].first['startDate']).to include(
        'year' => '1985',
        'month' => '1',
        'day' => '1'
      )
    end

    context "when 'treatments.startDate' is not included" do
      it "does not include 'treatment.startDate' after transformation" do
        treatments = [
          {
            'center' => {
              'name' => 'Some Treatment Center',
              'country' => 'United States of America'
            },
            'treatedDisabilityNames' => [
              'PTSD (post traumatic stress disorder)'
            ]
          }
        ]

        pending_record.form_data['treatments'] = treatments

        payload = JSON.parse(pending_record.to_internal)
        expect(payload['form526']['treatments'].first['startDate']).to be_nil
      end
    end
  end

  describe "breaking out 'treatments.endDate'" do
    it 'breaks it out by year, month, day' do
      treatments = [
        {
          'center' => {
            'name' => 'Some Treatment Center',
            'country' => 'United States of America'
          },
          'treatedDisabilityNames' => [
            'PTSD (post traumatic stress disorder)'
          ],
          'startDate' => '1985-01-01',
          'endDate' => '1986-01-01'
        }
      ]

      pending_record.form_data['treatments'] = treatments

      payload = JSON.parse(pending_record.to_internal)
      expect(payload['form526']['treatments'].first['endDate']).to include(
        'year' => '1986',
        'month' => '1',
        'day' => '1'
      )
    end
  end

  describe "assigning 'applicationExpirationDate'" do
    context "when 'applicationExpirationDate' is not provided" do
      it 'assigns a value 1 year from today' do
        pending_record.form_data.delete('applicationExpirationDate')

        payload = JSON.parse(pending_record.to_internal)
        application_expiration_date = Date.parse(payload['form526']['applicationExpirationDate'])
        expect(application_expiration_date).to eq(Time.zone.now.to_date + 1.year)
      end
    end

    context "when 'applicationExpirationDate' is provided" do
      it 'leaves the original provided value' do
        original_value = Date.parse(pending_record.form_data['applicationExpirationDate'])
        payload = JSON.parse(pending_record.to_internal)
        application_expiration_date = Date.parse(payload['form526']['applicationExpirationDate'])
        expect(original_value).to eq(application_expiration_date)
      end
    end
  end

  describe 'massaging invalid disability names' do
    describe "handling the length of a 'disability.name'" do
      context "when a 'disability.name' is longer than 255 characters" do
        it 'truncates it' do
          invalid_length_name = 'X' * 300
          pending_record.form_data['disabilities'].first['name'] = invalid_length_name

          payload = JSON.parse(pending_record.to_internal)
          disability_name = payload['form526']['disabilities'].first['name']

          expect(disability_name.length).to eq(255)
        end
      end

      context "when a 'disability.name' is shorter than 255 characters" do
        it 'does not change it' do
          valid_length_name = 'X' * 20
          pending_record.form_data['disabilities'].first['name'] = valid_length_name

          payload = JSON.parse(pending_record.to_internal)
          disability_name = payload['form526']['disabilities'].first['name']

          expect(valid_length_name).to eq(disability_name)
        end
      end

      context "when a 'disability.name' is exactly 255 characters" do
        it 'does not change it' do
          valid_length_name = 'X' * 255
          pending_record.form_data['disabilities'].first['name'] = valid_length_name

          payload = JSON.parse(pending_record.to_internal)
          disability_name = payload['form526']['disabilities'].first['name']

          expect(valid_length_name).to eq(disability_name)
        end
      end
    end

    describe "handling invalid characters in a 'disability.name'" do
      context "when a 'disability.name' has invalid characters" do
        it 'the invalid characters are removed' do
          name_with_invalid_characters = 'abc `~!@#$%^&*=+123'
          pending_record.form_data['disabilities'].first['name'] = name_with_invalid_characters

          payload = JSON.parse(pending_record.to_internal)
          disability_name = payload['form526']['disabilities'].first['name']

          expect(disability_name.include?('abc 123')).to be(true)
          expect(disability_name.include?('`')).to be(false)
          expect(disability_name.include?('~')).to be(false)
          expect(disability_name.include?('!')).to be(false)
          expect(disability_name.include?('@')).to be(false)
          expect(disability_name.include?('#')).to be(false)
          expect(disability_name.include?('$')).to be(false)
          expect(disability_name.include?('%')).to be(false)
          expect(disability_name.include?('^')).to be(false)
          expect(disability_name.include?('&')).to be(false)
          expect(disability_name.include?('*')).to be(false)
          expect(disability_name.include?('=')).to be(false)
          expect(disability_name.include?('+')).to be(false)
        end
      end

      context "when a 'disability.name' only has valid characters" do
        it 'nothing is changed' do
          name_with_only_valid_characters = "abc -'.,/()123"
          pending_record.form_data['disabilities'].first['name'] = name_with_only_valid_characters

          payload = JSON.parse(pending_record.to_internal)
          disability_name = payload['form526']['disabilities'].first['name']

          expect(name_with_only_valid_characters).to eq(disability_name)
        end
      end
    end
  end

  describe "'remove_encrypted_fields' callback" do
    context "when 'status' is 'established'" do
      let(:auto_form) { create(:auto_established_claim, :established, auth_headers: { some: 'data' }) }

      context 'and the record is updated' do
        it "erases the 'form_data' attribute" do
          expect(auto_form.form_data).not_to be_empty

          auto_form.auth_headers = { message: 'just need to update something to trigger the callback' }
          auto_form.save!
          auto_form.reload

          expect(auto_form.form_data).to be_empty
        end

        it "does not erase the 'auth_headers' attribute" do
          expect(auto_form.auth_headers).not_to be_empty

          auto_form.auth_headers = { message: 'just need to update something to trigger the callback' }
          auto_form.save!
          auto_form.reload

          expect(auto_form.auth_headers).not_to be_empty
        end

        it "does not erase the 'file_data' attribute" do
          auto_form = build(:auto_established_claim, :established, auth_headers: { some: 'data' })
          file = Rack::Test::UploadedFile.new(
            Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
          )

          auto_form.set_file_data!(file, 'docType')
          auto_form.save!
          auto_form.reload

          expect(auto_form.file_data).not_to be_nil

          auto_form.auth_headers = { message: 'just need to update something to trigger the callback' }
          auto_form.save!
          auto_form.reload

          expect(auto_form.file_data).not_to be_nil
        end
      end
    end
  end
end
