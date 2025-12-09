# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/associated_person'

describe VAProfile::Models::AssociatedPerson do
  subject { described_class.new(attributes) }

  let(:attributes) do
    {
      contact_type: 'Other emergency contact',
      given_name: 'DEBORAH',
      middle_name: 'LYNN',
      family_name: 'WILLIAMS',
      relationship: 'UNRELATED FRIEND',
      address_line1: '2645 TEST WAY',
      address_line2: 'UNIT 192',
      address_line3: '',
      city: 'CLEARWATER',
      state: 'FL',
      zip_code: '33760',
      primary_phone: '(321)555-1212'
    }
  end

  context 'Virtus::Attribute, Vets::Type::TitlecaseString type attributes' do
    it 'titlecases given_name' do
      expect(subject.given_name).to eq('Deborah')
    end

    it 'titlecases middle_name' do
      expect(subject.middle_name).to eq('Lynn')
    end

    it 'titlecases family_name' do
      expect(subject.family_name).to eq('Williams')
    end
  end

  context 'Virtus::Attribute, String type attributes' do
    %i[
      contact_type
      relationship
      address_line1
      address_line2
      address_line3
      city
      state
      zip_code
      primary_phone
    ].each do |attr|
      it "has unmodified #{attr} attribute" do
        expect(subject.send(attr)).to eq(attributes[attr])
      end
    end
  end
end
