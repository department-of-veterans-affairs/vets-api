# frozen_string_literal: true

require 'timecop'

require 'rails_helper'

RSpec.describe DependentsVerification::FormProfiles::VA210538, type: :model do
  subject { described_class.new(form_id:, user:) }

  let(:user) { build(:user, :loa3) }
  let(:form_id) { '21-0538' }
  let(:dependent_service) { instance_double(BGS::DependentService) }
  let(:dependents_data) do
    { number_of_records: '1', persons: [{
      award_indicator: 'Y',
      date_of_birth: '01/02/1960',
      email_address: 'test@email.com',
      first_name: 'JANE',
      last_name: 'WEBB',
      middle_name: 'M',
      ptcpnt_id: '600140899',
      related_to_vet: 'Y',
      relationship: 'Spouse',
      ssn: '222883214',
      veteran_indicator: 'N'
    }] }
  end
  let(:veteran_information) do
    { 'fullName' => { 'first' => 'Abraham', 'last' => 'Lincoln', 'suffix' => 'Jr.' },
      'ssnLastFour' => '1863', 'birthDate' => '1809-02-12' }
  end
  let(:contact_information) do
    { 'veteranAddress' => {
        'street' => '140 Rock Creek Rd',
        'city' => 'Washington',
        'state' => 'DC',
        'country' => 'USA',
        'postalCode' => '20011'
      },
      'mobilePhone' => '3035551234',
      'homePhone' => '3035551234',
      'usPhone' => '3035551234',
      'emailAddress' => be_a(String) }
  end
  let(:dependents_information) do
    [{
      'fullName' => { 'first' => 'JANE', 'middle' => 'M', 'last' => 'WEBB' },
      'dateOfBirth' => '1960-01-02',
      'ssn' => '222883214',
      'age' => 59,
      'relationshipToVeteran' => 'Spouse'
    }]
  end
  let(:metadata) do
    { version: 0, prefill: true, returnUrl: '/veteran-information' }
  end

  before do
    Timecop.freeze(Time.zone.local(2020, 1, 1))
    allow(FormProfile).to receive(:prefill_enabled_forms).and_return([form_id])
  end

  describe '#metadata' do
    it 'returns correct metadata' do
      expect(subject.metadata).to eq(metadata)

      subject.metadata
    end
  end

  describe '#prefill' do
    it 'initializes identity and contact information' do
      # Mock the dependent service to return inactive dependents
      VCR.use_cassette('bgs/claimant_web_service/dependents') do
        expect(subject.prefill).to match({ form_data: {
                                             'veteranInformation' => veteran_information,
                                             'veteranContactInformation' => contact_information
                                           },
                                           metadata: })
      end
    end

    it 'returns formatted dependent information' do
      # Mock the dependent service to return active dependents
      allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
      allow(dependent_service).to receive(:get_dependents).and_return(dependents_data)
      expect(subject.prefill).to match(({ form_data: {
                                            'veteranInformation' => veteran_information,
                                            'veteranContactInformation' => contact_information,
                                            'dependents' => dependents_information
                                          },
                                          metadata: }))
    end

    it 'handles a dependent information error' do
      # Mock the dependent service to return an error
      allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
      allow(dependent_service).to receive(:get_dependents).and_raise(
        StandardError.new('Dependent information error')
      )
      expect(subject.prefill).to match({ form_data: {
                                           'veteranInformation' => veteran_information,
                                           'veteranContactInformation' => contact_information
                                         },
                                         metadata: })
    end

    it 'handles missing dependents data' do
      # Mock the dependent service to return no dependents
      allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
      allow(dependent_service).to receive(:get_dependents).and_return(nil)
      expect(subject.prefill).to match({ form_data: {
                                           'veteranInformation' => veteran_information,
                                           'veteranContactInformation' => contact_information
                                         },
                                         metadata: })
    end

    it 'handles a contact information error' do
      allow(FormContactInformation).to receive(:new).and_raise(
        StandardError.new('Contact information error')
      )
      expect(subject.prefill).to match({ form_data: { 'veteranInformation' => veteran_information },
                                         metadata: })
    end

    it 'handles an identity information error' do
      allow(FormIdentityInformation).to receive(:new).and_raise(
        StandardError.new('Veteran information error')
      )
      expect(subject.prefill).to match({ form_data: { 'veteranContactInformation' => contact_information },
                                         metadata: })
    end

    describe 'initialize_dependents_information' do
      it 'returns an empty array when no dependents are found' do
        allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
        allow(dependent_service).to receive(:get_dependents).and_return({ number_of_records: '0', persons: [] })
        expect(subject.send(:initialize_dependents_information)).to eq([])
      end

      it 'returns an empty array BGS returns no data' do
        allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
        allow(dependent_service).to receive(:get_dependents).and_return(nil)
        expect(subject.send(:initialize_dependents_information)).to eq([])
      end

      it 'returns dependents mapped to DependentInformation model' do
        allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
        allow(dependent_service).to receive(:get_dependents).and_return(dependents_data)
        expect(subject.send(:initialize_dependents_information)).to all(
          be_a(DependentsVerification::DependentInformation)
        )
      end

      it 'handles invalid date formats gracefully' do
        invalid_date_data = dependents_data.dup
        invalid_date_data[:persons][0][:date_of_birth] = 'invalid-date'

        allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
        allow(dependent_service).to receive(:get_dependents).and_return(invalid_date_data)

        dependents = subject.send(:initialize_dependents_information)
        expect(dependents).to all(be_a(DependentsVerification::DependentInformation))
        expect(dependents.first.date_of_birth).to be_nil
        expect(dependents.first.age).to be_nil
      end

      it 'handles nil date gracefully' do
        nil_date_data = dependents_data.dup
        nil_date_data[:persons][0][:date_of_birth] = nil

        allow(BGS::DependentService).to receive(:new).with(user).and_return(dependent_service)
        allow(dependent_service).to receive(:get_dependents).and_return(nil_date_data)

        dependents = subject.send(:initialize_dependents_information)
        expect(dependents).to all(be_a(DependentsVerification::DependentInformation))
        expect(dependents.first.date_of_birth).to be_nil
        expect(dependents.first.age).to be_nil
      end
    end
  end
end
