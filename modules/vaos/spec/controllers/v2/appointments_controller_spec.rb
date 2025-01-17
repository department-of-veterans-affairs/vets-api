# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::AppointmentsController, type: :request do
  describe '#start_date' do
    context 'with an invalid date' do
      it 'throws an InvalidFieldValue exception' do
        subject.params = { start: 'not a date', end: '2022-09-21T00:00:00+00:00' }

        expect do
          subject.send(:start_date)
        end.to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#end_date' do
    context 'with an invalid date' do
      it 'throws an InvalidFieldValue exception' do
        subject.params = { end: 'not a date', start: '2022-09-21T00:00:00+00:00' }

        expect do
          subject.send(:end_date)
        end.to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#build_patient_attributes' do
    it 'builds correctly' do
      patient_params = subject.send(:patient_attributes, {
                                      name: {
                                        family: 'Smith',
                                        given: %w[
                                          Sarah
                                          Elizabeth
                                        ]
                                      },
                                      birth_date: '1985-03-15',
                                      email: 'sarah.smith@email.com',
                                      gender: 'female',
                                      phone_number: '407-555-8899',
                                      address: {
                                        city: 'Orlando',
                                        country: 'USA',
                                        line: [
                                          '742 Sunshine Boulevard',
                                          'Apt 15B'
                                        ],
                                        postal_code: '32801',
                                        state: 'FL',
                                        type: 'both',
                                        text: 'text'
                                      }
                                    })

      expect(patient_params[:address]).not_to include(:text)
      expect(patient_params[:address][:city]).to eql('Orlando')
      expect(patient_params[:address][:country]).to eql('USA')
      expect(patient_params[:address][:line].length).to be(2)
      expect(patient_params[:address][:line][0]).to eql('742 Sunshine Boulevard')
      expect(patient_params[:address][:line][1]).to eql('Apt 15B')
      expect(patient_params[:address][:postalCode]).to eql('32801')
      expect(patient_params[:address][:state]).to eql('FL')
      expect(patient_params[:address][:type]).to eql('both')
      expect(patient_params[:name][:family]).to eql('Smith')
      expect(patient_params[:name][:given].length).to be(2)
      expect(patient_params[:name][:given][0]).to eql('Sarah')
      expect(patient_params[:name][:given][1]).to eql('Elizabeth')
      expect(patient_params[:email]).to eql('sarah.smith@email.com')
      expect(patient_params[:gender]).to eql('female')
      expect(patient_params[:birthDate]).to eql('1985-03-15')
      expect(patient_params[:phone]).to eql('407-555-8899')
    end
  end
end
