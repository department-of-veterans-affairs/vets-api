# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/data_translation'

describe EVSS::DisabilityCompensationForm::DataTranslation do
  let(:form_content) { JSON.parse(File.read('spec/support/disability_compensation_form/front_end_submission.json')) }
  let(:evss_json) { File.read 'spec/support/disability_compensation_form/evss_submission.json' }
  let(:user) { build(:disabilities_compensation_user) }

  before do
    User.create(user)
  end

  subject { described_class.new(user, form_content) }

  describe '#convert' do
    before do
      create(:in_progress_form, form_id: VA526ez::FORM_ID, user_uuid: user.uuid)
      allow_any_instance_of(EMISRedis::MilitaryInformation).to receive(:service_episodes_by_date).and_return([])
    end

    it 'should return correctly formatted json to send to EVSS' do
      VCR.use_cassette('evss/ppiu/payment_information') do
        VCR.use_cassette('evss/intent_to_file/active_compensation') do
          expect(JSON.parse(subject.convert)).to eq JSON.parse(evss_json)
        end
      end
    end
  end

  describe '#get_address_type' do
    context 'when given an a US address' do
      let(:address) { { 'country' => 'USA', 'state' => 'OR' } }

      it 'should return "DOMESTIC"' do
        expect(subject.send(:get_address_type, address)).to eq 'DOMESTIC'
      end
    end

    context 'when given a military address' do
      let(:address) { { 'country' => 'USA', 'state' => 'AA' } }

      it 'should return "MILITARY"' do
        expect(subject.send(:get_address_type, address)).to eq 'MILITARY'
      end
    end

    context 'when given an international address' do
      let(:address) { { 'country' => 'MEX' } }

      it 'should return "INTERNATIONAL"' do
        expect(subject.send(:get_address_type, address)).to eq 'INTERNATIONAL'
      end
    end
  end

  describe '#split_zip_code' do
    context 'when given a 5 number zip code' do
      it 'should return the correct split' do
        expect(subject.send(:split_zip_code, '12345')).to eq ['12345', '', nil]
      end
    end

    context 'when given a 9 number zip code' do
      it 'should return the correct split' do
        expect(subject.send(:split_zip_code, '123456789')).to eq ['12345', '', '6789']
      end
    end

    context 'when given a 9 number zip code with a hyphen' do
      it 'should return the correct split' do
        expect(subject.send(:split_zip_code, '12345-6789')).to eq ['12345', '-', '6789']
      end
    end
  end

  describe '#convert_mailing_address' do
    context 'when the address is DOMESTIC' do
      let(:address) do
        {
          'country' => 'USA',
          'addressLine1' => '123 South Frampington St.',
          'state' => 'OR',
          'zipCode' => '12345',
          'city' => 'Salem'
        }
      end

      it 'should transform the address correctly' do
        result_hash = {
          'type' => 'DOMESTIC',
          'country' => 'USA',
          'addressLine1' => '123 South Frampington St.',
          'city' => 'Salem',
          'state' => 'OR',
          'zipFirstFive' => '12345'
        }
        expect(subject.send(:convert_mailing_address, address)).to eq result_hash
      end
    end

    context 'when the address is MILITARY' do
      let(:address) do
        {
          'country' => 'USA',
          'addressLine1' => '123 South Frampington St.',
          'state' => 'AA',
          'city' => 'ASO'
        }
      end

      it 'should transform the address correctly' do
        result_hash = {
          'type' => 'MILITARY',
          'country' => 'USA',
          'addressLine1' => '123 South Frampington St.',
          'militaryPostOfficeTypeCode' => 'ASO',
          'militaryStateCode' => 'AA'
        }
        expect(subject.send(:convert_mailing_address, address)).to eq result_hash
      end
    end

    context 'when the address is INTERNATIONAL' do
      let(:address) do
        {
          'country' => 'MEX',
          'addressLine1' => '123 Buena Vista St.',
          'city' => 'Mexico City'
        }
      end

      it 'should transform the address correctly' do
        result_hash = {
          'type' => 'INTERNATIONAL',
          'country' => 'MEX',
          'addressLine1' => '123 Buena Vista St.',
          'city' => 'Mexico City'
        }
        expect(subject.send(:convert_mailing_address, address)).to eq result_hash
      end
    end
  end

  describe '#split_phone_number' do
    context 'when given a phone number' do
      it 'should correctly split the number' do
        result_hash = {
          'phoneNumber' => '1234567',
          'areaCode' => '555'
        }
        expect(subject.send(:split_phone_number, '5551234567')).to eq result_hash
      end
    end
  end

  describe '#service_branch' do
    context 'when the service branch is NOAA' do
      it 'should transform it to the correct string' do
        expect(subject.send(:service_branch, 'NOAA')).to eq 'National Oceanic &amp; Atmospheric Administration'
      end
    end

    context 'when the service branch is not NOAA' do
      it 'should keep the service branch as is' do
        expect(subject.send(:service_branch, 'Navy')).to eq 'Navy'
      end
    end
  end

  describe '#convert_homelessness' do
    context 'when point of contact is empty' do
      it 'should return the correct hash' do
        result_hash = { 'hasPointOfContact' => false }
        expect(subject.send(:convert_homelessness, nil)).to eq result_hash
      end
    end

    context 'when there is a point of contact' do
      let(:point_of_contact) do
        {
          'pointOfContactName' => 'Steve Stevington',
          'primaryPhone' => '5551234567'
        }
      end

      it 'should return the correct hash' do
        result_hash = {
          'hasPointOfContact' => true,
          'pointOfContact' => {
            'pointOfContactName' => 'Steve Stevington',
            'primaryPhone' => {
              'phoneNumber' => '1234567',
              'areaCode' => '555'
            }
          }
        }
        expect(subject.send(:convert_homelessness, point_of_contact)).to eq result_hash
      end
    end
  end

  describe '#get_banking_info' do
    context 'when the account exists' do
      let(:payment_info) do
        {
          'accountType' => 'CHECKING',
          'accountNumber' => '9876543211234',
          'routingNumber' => '042102115',
          'bankName' => 'Comerica'
        }
      end

      it 'should translate the payment information correctly' do
        VCR.use_cassette('evss/ppiu/payment_information') do
          expect(subject.send(:get_banking_info)).to eq payment_info
        end
      end
    end
  end

  describe '#application_expiration_date' do
    let(:past) { Time.zone.now - 1.month }
    let(:now) { Time.zone.now }
    let(:future) { Time.zone.now + 1.month }

    context 'when the RAD date is more recent than the application creation date' do
      before do
        allow(subject).to receive(:application_create_date).and_return(past)
        allow(subject).to receive(:rad_date).and_return(now)
      end

      it 'should return the RAD date + 366 days' do
        return_date = (now + 366.days).iso8601
        expect(subject.send(:application_expiration_date)).to eq return_date
      end
    end

    context 'when the RAD date does not exist' do
      before do
        allow(subject).to receive(:rad_date).and_return(nil)
      end

      let!(:itf) do
        EVSS::IntentToFile::IntentToFile.new(
          'status' => 'active',
          'type' => 'compensation',
          'creation_date' => nil,
          'expiration_date' => nil
        )
      end

      context 'when the ITF creation date is nil' do
        before do
          allow(subject).to receive(:application_create_date).and_return(now)
          allow(subject).to receive(:itf).and_return(itf)
        end

        it 'should return the application creation date + 365 days' do
          return_date = (now + 365.days).iso8601
          expect(subject.send(:application_expiration_date)).to eq return_date
        end
      end

      context 'when the ITF expiration date is nil' do
        before do
          allow(subject).to receive(:application_create_date).and_return(now)
          itf.creation_date = past
          allow(subject).to receive(:itf).and_return(itf)
        end

        it 'should return the application creation date + 365 days' do
          return_date = (now + 365.days).iso8601
          expect(subject.send(:application_expiration_date)).to eq return_date
        end
      end

      context 'when the ITF creation date is more recent than the application creation date' do
        before do
          allow(subject).to receive(:application_create_date).and_return(past)
          itf.creation_date = now
          itf.expiration_date = future
          allow(subject).to receive(:itf).and_return(itf)
        end

        it 'should return the application creation date + 365 days' do
          return_date = (past + 365.days).iso8601
          expect(subject.send(:application_expiration_date)).to eq return_date
        end
      end

      context 'when the ITF creation date isolder than the application creation date' do
        before do
          allow(subject).to receive(:application_create_date).and_return(now)
          itf.creation_date = past
          itf.expiration_date = future
          allow(subject).to receive(:itf).and_return(itf)
        end

        it 'should return the application creation date + 365 days' do
          expect(subject.send(:application_expiration_date)).to eq itf.expiration_date.iso8601
        end
      end
    end
  end
end
