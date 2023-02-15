# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MedicalCopays::ZeroBalanceStatements do
  subject { described_class }

  let(:statements) { [{ 'foo' => 'bar' }] }
  let(:facility_hash) { { 'foo' => ['123'] } }
  let(:today_date) { Time.zone.today.strftime('%m%d%Y') }

  let(:default_params) { { statements: statements, facility_hash: facility_hash } }

  let(:vha_358_attributes) do
    {
      id: 'vha_358',
      type: 'va_facilities',
      name: 'Manila VA Clinic',
      facility_type: 'va_health_facility',
      classification: 'Other Outpatient Services (OOS)',
      website: nil,
      lat: 14.54408,
      long: 120.99139,
      address: {
        'mailing' => {},
        'physical' => {
          'address_1' => '1501 Roxas Boulevard',
          'address_2' => 'NOX3 Seafront Compound',
          'address_3' => nil,
          'city' => 'Pasay City',
          'state' => 'PH',
          'zip' => '01302'
        }
      },
      phone: {
        'after_hours' => nil,
        'enrollment_coordinator' => '632-550-3888 x3780',
        'fax' => '632-310-5962',
        'main' => '632-550-3888',
        'patient_advocate' => '632-550-3888 x3716',
        'pharmacy' => '632-550-3888 x5029'
      },
      hours: {
        'friday' => '730AM-430PM',
        'monday' => '730AM-430PM',
        'saturday' => 'Closed',
        'sunday' => 'Closed',
        'thursday' => '730AM-430PM',
        'tuesday' => '730AM-430PM',
        'wednesday' => '730AM-430PM'
      },
      services: { 'health' => %w[Audiology Cardiology Dermatology EmergencyCare
                                 Ophthalmology PrimaryCare SpecialtyCare],
                  'last_updated' => '2021-04-05', 'other' => [] },
      feedback: {
        'effective_date' => '2021-03-05',
        'health' => {
          'primary_care_urgent' => 0.0,
          'primary_care_routine' => 0.9100000262260437,
          'specialty_care_urgent' => 0.0,
          'specialty_care_routine' => 0.0
        }
      },
      access: {
        'effective_date' => '2021-04-05',
        'health' => [
          { 'service' => 'Audiology',        'new' => 103.0,      'established' => 73.833333 },
          { 'service' => 'Cardiology',       'new' => 42.285714,  'established' => 19.053571 },
          { 'service' => 'Dermatology',      'new' => 140.25,     'established' => 18.666666 },
          { 'service' => 'Ophthalmology',    'new' => 131.0,      'established' => 33.333333 },
          { 'service' => 'PrimaryCare',      'new' => 30.111111,  'established' => 29.153846 },
          { 'service' => 'SpecialtyCare',    'new' => 76.986666,  'established' => 38.891509 }
        ]
      },
      mobile: false,
      active_status: 'A',
      visn: '21',
      operating_status: { 'code' => 'NORMAL' },
      operational_hours_special_instructions: nil,
      facility_type_prefix: 'vha',
      unique_id: '358'
    }
  end

  before do
    allow_any_instance_of(Lighthouse::Facilities::Client).to receive(:get_facilities).and_return([])
  end

  describe 'attributes' do
    it 'responds to statements' do
      expect(subject.build(default_params).respond_to?(:statements)).to be(true)
    end

    it 'responds to facility_hash' do
      expect(subject.build(default_params).respond_to?(:facility_hash)).to be(true)
    end

    it 'responds to facilities' do
      expect(subject.build(default_params).respond_to?(:facilities)).to be(true)
    end
  end

  describe '.build' do
    it 'returns an instance of ZeroBalanceStatements' do
      expect(subject.build(default_params)).to be_an_instance_of(described_class)
    end
  end

  describe '#list' do
    context 'there exists a facility with a zero balance' do
      before do
        allow_any_instance_of(Lighthouse::Facilities::Client).to receive(:get_facilities).and_return(
          [
            Lighthouse::Facilities::Facility.new(
              {
                'id' => 'vha_358',
                'type' => 'facility',
                'attributes' => vha_358_attributes
              }
            )
          ]
        )
      end

      let(:statements) { [] }
      let(:facility_hash) { { '358' => ['123456'] } }

      let(:listed_zero_balances) do
        [
          {
            'pH_AMT_DUE' => 0,
            'pS_STATEMENT_DATE' => today_date,
            'station' => {
              'facilitY_NUM' => '358',
              'city' => 'PASAY CITY'
            }
          }
        ]
      end

      it 'lists the zero balance facility in VBS format' do
        expect(subject.build(statements: statements, facility_hash: facility_hash).list).to eq(listed_zero_balances)
      end
    end

    context 'there exists a duplicated facility with a zero balance' do
      before do
        allow_any_instance_of(Lighthouse::Facilities::Client).to receive(:get_facilities).and_return(
          [
            Lighthouse::Facilities::Facility.new(
              {
                'id' => 'vha_358',
                'type' => 'facility',
                'attributes' => vha_358_attributes
              }
            )
          ]
        )
      end

      let(:statements) { [] }
      let(:facility_hash) { { '358' => ['123456'], '359' => ['654321'] } }

      let(:listed_zero_balances) do
        [
          {
            'pH_AMT_DUE' => 0,
            'pS_STATEMENT_DATE' => today_date,
            'station' => {
              'facilitY_NUM' => '358',
              'city' => 'PASAY CITY'
            }
          }
        ]
      end

      it 'lists only the one facility for zero balances' do
        expect(subject.build(statements: statements, facility_hash: facility_hash).list).to eq(listed_zero_balances)
      end
    end

    context 'there exists multiple facilities with zero balance' do
      before do
        allow_any_instance_of(Lighthouse::Facilities::Client).to receive(:get_facilities).and_return(
          [
            Lighthouse::Facilities::Facility.new(
              {
                'id' => 'vha_358',
                'type' => 'facility',
                'attributes' => vha_358_attributes
              }
            ),
            Lighthouse::Facilities::Facility.new(
              {
                'id' => 'vha_359',
                'type' => 'facility',
                'attributes' => {
                  'address' => {
                    'physical' => {
                      'city' => 'Des Moines'
                    }
                  }
                }
              }
            )
          ]
        )
      end

      let(:statements) { [] }
      let(:facility_hash) { { '358' => ['123456'], '359' => ['123456'] } }

      let(:listed_zero_balances) do
        [
          {
            'pH_AMT_DUE' => 0,
            'pS_STATEMENT_DATE' => today_date,
            'station' => {
              'facilitY_NUM' => '358',
              'city' => 'PASAY CITY'
            }
          },
          {
            'pH_AMT_DUE' => 0,
            'pS_STATEMENT_DATE' => today_date,
            'station' => {
              'facilitY_NUM' => '359',
              'city' => 'DES MOINES'
            }
          }
        ]
      end

      it 'lists the zero balance facility in VBS format' do
        expect(subject.build(statements: statements, facility_hash: facility_hash).list).to eq(listed_zero_balances)
      end
    end

    context 'the only facility already has a balance' do
      before do
        allow_any_instance_of(Lighthouse::Facilities::Client).to receive(:get_facilities).and_return(
          [
            Lighthouse::Facilities::Facility.new(
              {
                'id' => 'vha_358',
                'type' => 'facility',
                'attributes' => vha_358_attributes
              }
            )
          ]
        )
      end

      let(:statements) do
        [
          {
            'pS_FACILITY_NUM' => '358'
          }
        ]
      end

      let(:facility_hash) { { '358' => ['123456'] } }

      it 'returns empty array' do
        expect(subject.build({ statements: statements, facility_hash: facility_hash }).list).to eq([])
      end
    end

    context 'Service request errors' do
      it 'returns empty array on http timeout' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        expect(subject.build(default_params).list).to eq([])
      end

      it 'returns empty array on any generic service error' do
        allow_any_instance_of(Lighthouse::Facilities::Client).to receive(:get_facilities).and_raise(
          Common::Exceptions::BackendServiceException
        )
        expect(subject.build(default_params).list).to eq([])
      end
    end
  end
end
