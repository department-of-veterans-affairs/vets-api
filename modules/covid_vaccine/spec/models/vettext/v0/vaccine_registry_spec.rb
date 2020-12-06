# frozen_string_literal: true

require 'rails_helper'

describe Vetext::V0::VaccineRegistry, type: :model do
  let(:user) { build(:user, :vaos) }

  context 'unauthenticateed and no mvi lookup' do
    # TODO: need additional specs for when user is unauthenticated, and MVI lookup fails to return a match
  end

  context 'unauthenticated with mvi lookup' do
    # TODO: need additional specs for when user is unauthenticated, but attribuets result in MVI lookup
  end

  context 'authenticated', :aggregate_failures do
    subject { build(:vaccine_registry, :auth, user: user) }

    it 'has patient icn from mvi' do
      expect(subject.patient_icn).to eq(user.icn)
    end

    xit 'has facility station numbers from mvi' do
      # TODO: This is derived from va_profile vha_facility_ids somehow?
      expect(subject.sta3n).to eq('')
      expect(subject.sta6a).to eq('')
    end

    it 'has authenticated true' do
      expect(subject.authenticated).to eq(true)
    end

    it 'has first_name, last_name, middle_name, gender, date_of_birth, patient_ssn from mvi' do
      expect(subject.first_name).to eq(user.first_name)
      expect(subject.last_name).to eq(user.last_name)
      expect(subject.middle_name).to eq(user.middle_name)
      expect(subject.gender).to eq(user.gender)
      expect(subject.date_of_birth).to eq(user.birth_date)
      expect(subject.patient_ssn).to eq(user.ssn)
    end

    it 'has other fields from request body' do
      expect(subject.vaccine_interest).to eq('yes')
      expect(subject.date_vaccine_received).to eq('')
      expect(subject.contact).to eq(true)
      expect(subject.contact_method).to eq('phone')
      expect(subject.reason_undecided).to eq('')
      expect(subject.phone).to eq('555-555-1234')
      expect(subject.email).to eq('judy.morrison@email.com')
    end

    it 'returns attributes' do
      expect(subject.attributes).to eq(
        {
          patient_icn: '1012845331V153043',
          sta3n: '',
          sta6a: '',
          authenticated: true,
          vaccine_interest: 'yes',
          date_vaccine_received: '',
          contact: true,
          contact_method: 'phone',
          reason_undecided: '',
          phone: '555-555-1234',
          email: 'judy.morrison@email.com',
          first_name: 'Judy',
          middle_initial: nil,
          last_name: 'Morrison',
          gender: 'F',
          date_of_birth: '1953-04-01',
          patient_ssn: '796061976'
        }
      )
    end
  end
end
