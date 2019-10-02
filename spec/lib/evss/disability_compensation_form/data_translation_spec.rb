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

  subject { described_class.new(user, form_content, false) }

  describe '#translate' do
    before do
      create(:in_progress_form, form_id: VA526ez::FORM_ID, user_uuid: user.uuid)
    end

    it 'should return correctly formatted json to send to EVSS' do
      VCR.use_cassette('evss/ppiu/payment_information') do
        VCR.use_cassette('evss/intent_to_file/active_compensation') do
          VCR.use_cassette('emis/get_military_service_episodes/valid', allow_playback_repeats: true) do
            expect(subject.translate).to eq JSON.parse(evss_json)
          end
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

  describe '#translate_mailing_address' do
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
        expect(subject.send(:translate_mailing_address, address)).to eq result_hash
      end
    end

    context 'when the address is MILITARY' do
      let(:address) do
        {
          'country' => 'USA',
          'addressLine1' => '123 South Frampington St.',
          'state' => 'AA',
          'city' => 'ASO',
          'zipCode' => '12345-6789'
        }
      end

      it 'should transform the address correctly' do
        result_hash = {
          'type' => 'MILITARY',
          'country' => 'USA',
          'addressLine1' => '123 South Frampington St.',
          'militaryPostOfficeTypeCode' => 'ASO',
          'militaryStateCode' => 'AA',
          'zipFirstFive' => '12345',
          'zipLastFour' => '6789'
        }
        expect(subject.send(:translate_mailing_address, address)).to eq result_hash
      end
    end

    context 'when the address is INTERNATIONAL' do
      let(:address) do
        {
          'country' => 'Mexico',
          'addressLine1' => '123 Buena Vista St.',
          'city' => 'Mexico City'
        }
      end

      it 'should transform the address correctly' do
        result_hash = {
          'type' => 'INTERNATIONAL',
          'country' => 'Mexico',
          'addressLine1' => '123 Buena Vista St.',
          'city' => 'Mexico City',
          'internationalPostalCode' => '773'
        }
        expect(subject.send(:translate_mailing_address, address)).to eq result_hash
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
        expect(subject.send(:service_branch, 'NOAA')).to eq 'National Oceanic & Atmospheric Administration'
      end
    end

    context 'when the service branch is not NOAA' do
      it 'should keep the service branch as is' do
        expect(subject.send(:service_branch, 'Navy')).to eq 'Navy'
      end
    end
  end

  describe '#translate_treatments' do
    context 'when the veteran gives no treatment centers' do
      before do
        subject.instance_variable_set(
          :@form_content,
          'form526' => {
            'treatments' => []
          }
        )
      end

      it 'should delete the "treatments" key' do
        subject.send(:translate_treatments)
        expect(
          subject.instance_variable_get(:@form_content).dig('form526', 'treatments')
        ).to eq nil
      end
    end
  end

  describe '#translate_disabilities' do
    context 'there are special issues' do
      before do
        subject.instance_variable_set(
          :@form_content,
          'form526' => {
            'disabilities' => [
              {
                'specialIssues' => [{ 'code' => 'TRM' }]
              }
            ]
          }
        )
      end

      it 'should delete the "specialIssues" key' do
        subject.send(:translate_disabilities)
        expect(
          subject.instance_variable_get(:@form_content).dig('form526', 'disabilities', 0, 'specialIssues')
        ).to eq nil
      end
    end
  end

  describe '#translate_national_guard_service' do
    context 'when the veteran has a reserve/guard service' do
      before do
        subject.instance_variable_set(
          :@form_content,
          'form526' => {
            'serviceInformation' => {
              'reservesNationalGuardService' => {
                'obligationTermOfServiceDateRange' => {
                  'from' => '2018-03-29T18:50:03.015Z',
                  'to' => '2018-03-29T18:50:03.015Z'
                },
                'waiveVABenefitsToRetainTrainingPay' => false
              }
            }
          }
        )
      end

      it 'should translate the fields correctly' do
        result_hash = {
          'obligationTermOfServiceFromDate' => '2018-03-29T18:50:03.015Z',
          'obligationTermOfServiceToDate' => '2018-03-29T18:50:03.015Z',
          'inactiveDutyTrainingPay' => {
            'waiveVABenefitsToRetainTrainingPay' => false
          }
        }
        result = subject.send(
          :translate_national_guard_service, subject.instance_variable_get(
            :@form_content
          ).dig('form526', 'serviceInformation', 'reservesNationalGuardService')
        )
        expect(result).to eq result_hash
      end
    end
  end

  describe '#translate_homelessness' do
    context 'when the veteran is not homeless' do
      before do
        subject.instance_variable_set(
          :@form_content,
          'form526' => {
            'veteran' => {
              'homelessness' => {
                'isHomeless' => false
              }
            }
          }
        )
      end

      it 'should delete the "homelessness" key' do
        subject.send(:translate_homelessness)
        expect(
          subject.instance_variable_get(:@form_content).dig('form526', 'veteran', 'homelessness')
        ).to eq nil
      end
    end

    context 'when the veteran has no homeless point of contact' do
      before do
        subject.instance_variable_set(
          :@form_content,
          'form526' => {
            'veteran' => {
              'homelessness' => {
                'isHomeless' => true
              }
            }
          }
        )
      end

      it 'should add update the "homelessness" key correctly' do
        result_hash = {
          'hasPointOfContact' => false
        }
        subject.send(:translate_homelessness)
        expect(
          subject.instance_variable_get(:@form_content).dig('form526', 'veteran', 'homelessness')
        ).to eq result_hash
      end
    end

    context 'when the veteran has a homeless point of contact' do
      it 'should add update the "homelessness" key correctly' do
        result_hash = {
          'hasPointOfContact' => true,
          'pointOfContact' => {
            'pointOfContactName' => 'Ted',
            'primaryPhone' => {
              'phoneNumber' => '4567890',
              'areaCode' => '123'
            }
          }
        }
        subject.send(:translate_homelessness)
        expect(
          subject.instance_variable_get(:@form_content).dig('form526', 'veteran', 'homelessness')
        ).to eq result_hash
      end
    end
  end

  describe '#set_banking_info' do
    context 'when the payment information exists' do
      let(:payment_info) do
        {
          'accountType' => 'CHECKING',
          'accountNumber' => '9876543211234',
          'routingNumber' => '042102115',
          'bankName' => 'Comerica'
        }
      end

      it 'should set the payment information correctly' do
        VCR.use_cassette('evss/ppiu/payment_information') do
          subject.send(:set_banking_info)
          expect(
            subject.instance_variable_get(:@form_content).dig('form526', 'directDeposit')
          ).to eq payment_info
        end
      end
    end

    context 'when the payment information does not exist' do
      let(:response) do
        OpenStruct.new(
          get_payment_information: OpenStruct.new(
            responses: [OpenStruct.new(payment_account: nil)]
          )
        )
      end

      it 'should not set payment information' do
        expect(EVSS::PPIU::Service).to receive(:new).once.and_return(response)
        subject.send(:set_banking_info)
        expect(
          subject.instance_variable_get(:@form_content).dig('form526', 'directDeposit')
        ).to eq nil
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
