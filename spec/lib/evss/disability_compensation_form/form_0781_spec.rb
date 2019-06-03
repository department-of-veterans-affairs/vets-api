# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/form0781'

describe EVSS::DisabilityCompensationForm::Form0781 do
  let(:form_content) do
    JSON.parse(File.read('spec/support/disability_compensation_form/all_claims_with_0781_fe_submission.json'))
  end
  let(:user) { build(:disabilities_compensation_user) }

  before do
    User.create(user)
  end

  subject { described_class.new(user, form_content) }

  describe '#translate' do
    context 'when 781 data is present in the 526 form' do
      let(:expected_output) { JSON.parse(File.read('spec/support/disability_compensation_form/form_0781.json')) }

      it 'should return correctly formatted json to send to async job' do
        expect(subject.translate).to eq expected_output
      end
    end

    context 'when 781 is not present in the 526 form' do
      let(:form_content) { { 'form526' => {} } }

      it 'should return a nil value' do
        expect(subject.translate).to eq nil
      end
    end
  end

  describe '#create_form' do
    context 'when the form exists and has incidents' do
      let(:incidents) { 'this is a test' }

      it 'should create the form correctly' do
        expect(subject.send(:create_form, incidents)).to eq(
          'additionalIncidentText' => nil,
          'email' => 'test@email.com',
          'incidents' => 'this is a test',
          'otherInformation' => nil,
          'remarks' => nil,
          'vaFileNumber' => '796068949',
          'veteranDateOfBirth' => '1809-02-12',
          'veteranFullName' => {
            'first' => 'Beyonce', 'middle' => nil, 'last' => 'Knowles'
          },
          'veteranPhone' => '2024561111',
          'veteranSecondaryPhone' => '',
          'veteranServiceNumber' => '',
          'veteranSocialSecurityNumber' => '796068949'
        )
      end
    end
  end

  describe '#split_incidents' do
    context 'when there are no incidents' do
      let(:incidents) do
        [
          {
            'personalAssault' => true,
            'test' => 'foo1'
          },
          {
            'personalAssault' => true,
            'test' => 'foo2'
          },
          {
            'personalAssault' => false,
            'test' => 'bar1'
          },
          {
            'personalAssault' => false,
            'test' => 'bar2'
          }
        ]
      end

      it 'should split the incidents on personalAssualt' do
        expect(subject.send(:split_incidents, incidents)).to eq [
          [
            { 'personalAssault' => true, 'test' => 'foo1' },
            { 'personalAssault' => true, 'test' => 'foo2' }
          ],
          [
            { 'personalAssault' => false, 'test' => 'bar1' },
            { 'personalAssault' => false, 'test' => 'bar2' }
          ]
        ]
      end
    end

    context 'when there are no incidents' do
      let(:incidents) { [] }

      it 'should return a nil value' do
        expect(subject.send(:split_incidents, incidents)).to eq nil
      end
    end
  end

  describe '#join_location' do
    context 'when given a full address' do
      let(:location) do
        {
          'city' => 'Portland',
          'state' => 'OR',
          'country' => 'USA',
          'additionalDetails' => 'Apt. 1'
        }
      end

      it 'should join it into one string' do
        expect(subject.send(:join_location, location)).to eq 'Portland, OR, USA, Apt. 1'
      end
    end

    context 'when given a partial address' do
      let(:location) do
        {
          'city' => 'Portland',
          'state' => '',
          'country' => 'USA'
        }
      end

      it 'should join it into one string' do
        expect(subject.send(:join_location, location)).to eq 'Portland, USA'
      end
    end

    context 'when given no address' do
      let(:location) { {} }

      it 'should join it into one string' do
        expect(subject.send(:join_location, location)).to eq ''
      end
    end
  end

  describe '#full_name' do
    context 'when the user has a full name' do
      it 'should return a hash of their name' do
        expect(subject.send(:full_name)).to eq(
          'first' => 'Beyonce',
          'middle' => nil,
          'last' => 'Knowles'
        )
      end
    end
  end
end
