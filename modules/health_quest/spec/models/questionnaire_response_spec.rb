# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireResponse do
  subject { described_class.new }

  let(:user) do
    double(
      'User',
      icn: '1008596379V859838',
      account_uuid: 'abc123',
      birth_date: '01-01-1955',
      vet360_contact_info: double('Profile',
                                  mailing_address: '123 abc',
                                  residential_address: '123 abc',
                                  home_phone: '555-555-5555',
                                  mobile_phone: '555-555-5555',
                                  work_phone: '555-555-5555'),
      uuid: '789defg',
      first_name: 'Foo',
      middle_name: 'Baz',
      last_name: 'Bar',
      gender: 'M',
      address: '221B Baker Street'
    )
  end

  describe 'object initialization' do
    it 'responds to appointment_id' do
      expect(subject.respond_to?(:appointment_id)).to eq(true)
    end

    it 'responds to user_uuid' do
      expect(subject.respond_to?(:user_uuid)).to eq(true)
    end

    it 'responds to questionnaire_response_id' do
      expect(subject.respond_to?(:questionnaire_response_id)).to eq(true)
    end

    it 'responds to questionnaire_response_data' do
      expect(subject.respond_to?(:questionnaire_response_data)).to eq(true)
    end

    it 'responds to user_demographics_data' do
      expect(subject.respond_to?(:user_demographics_data)).to eq(true)
    end

    it 'responds to user' do
      expect(subject.respond_to?(:user)).to eq(true)
    end
  end

  describe 'validations' do
    it 'is not valid without questionnaire_response_data' do
      subject.questionnaire_response_data = nil

      expect(subject.valid?).to eq(false)
    end

    it 'is valid with questionnaire_response_data' do
      subject.questionnaire_response_data = { 'foo' => 'bar' }

      expect(subject.valid?).to eq(true)
    end
  end

  describe 'encryption' do
    before do
      subject.user = user
      subject.questionnaire_response_data = { 'foo' => 'bar' }
      subject.save
      subject.reload
    end

    it 'encrypts questionnaire_response_data' do
      expect(subject.encrypted_questionnaire_response_data).to be_a(String)
    end

    it 'encrypts user_demographics_data' do
      expect(subject.encrypted_user_demographics_data).to be_a(String)
    end
  end

  describe 'before_save' do
    before do
      subject.user = user
      subject.questionnaire_response_data = { 'foo' => 'bar' }
      subject.save
      subject.reload
    end

    it 'returns the user_demographics_data' do
      hash = {
        'first_name' => 'Foo',
        'middle_name' => 'Baz',
        'last_name' => 'Bar',
        'gender' => 'M',
        'date_of_birth' => '01-01-1955',
        'address' => '221B Baker Street',
        'mailing_address' => '123 abc',
        'home_address' => '123 abc',
        'home_phone' => '555-555-5555',
        'mobile_phone' => '555-555-5555',
        'work_phone' => '555-555-5555'
      }

      expect(subject.user_demographics_data).to eq(hash)
    end
  end
end
