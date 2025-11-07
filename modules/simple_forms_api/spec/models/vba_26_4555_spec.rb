# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::VBA264555 do
  describe 'veteran name' do
    it 'limits the length to 30 characters' do
      name = 'Wolfeschlegelsteinhausenbergerdorffwelchevoralternwarengewissenhaftschaferswessenschafe
      warenwohlgepflegeundsorgfaltigkeitbeschutzenvonangreifendurchihrraubgierigfeindewelchevoralternzwolftausend
      jahresvorandieerscheinenvanderersteerdemenschderraumschiffgebrauchlichtalsseinursprungvonkraftgestartsein
      langefahrthinzwischensternartigraumaufdersuchenachdiesternwelchegehabtbewohnbarplanetenkreisedrehensichund
      wohinderneurassevonverstandigmenschlichkeitkonntefortpflanzenundsicherfreuenanlebenslanglichfreudeundruhemit
      nichteinfurchtvorangreifenvonandererintelligentgeschopfsvonhinzwischensternartigraum'
      shortened_name = 'Wolfeschlegelsteinhausenberger'

      form = SimpleFormsApi::VBA264555.new(
        {
          'veteran' => {
            'full_name' => {
              'first' => name,
              'middle' => name,
              'last' => name
            }
          }
        }
      )

      expect(shortened_name.length).to eq 30
      expect(form.as_payload[:veteran][:fullName][:first]).to eq shortened_name
      expect(form.as_payload[:veteran][:fullName][:middle]).to eq shortened_name
      expect(form.as_payload[:veteran][:fullName][:last]).to eq shortened_name
    end
  end

  describe 'veteran ssn' do
    it 'strips dashes out' do
      ssn = '987-65-4321'
      stripped_ssn = '987654321'

      form = SimpleFormsApi::VBA264555.new(
        {
          'veteran' => {
            'full_name' => {},
            'ssn' => ssn
          }
        }
      )

      expect(form.as_payload[:veteran][:ssn]).to eq stripped_ssn
    end
  end

  describe '#notification_first_name' do
    let(:data) do
      {
        'veteran' => {
          'full_name' => {
            'first' => 'Veteran',
            'last' => 'Eteranvay'
          }
        }
      }
    end

    it 'returns the first name to be used in notifications' do
      expect(described_class.new(data).notification_first_name).to eq 'Veteran'
    end
  end

  describe '#notification_email_address' do
    let(:data) do
      { 'veteran' => { 'email' => 'a@b.com' } }
    end

    it 'returns the email address to be used in notifications' do
      expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
    end
  end

  describe '#as_payload' do
    let(:form_data) do
      {
        'remarks' => 'Test remarks',
        'other_conditions' => 'Test conditions',
        'statement_of_truth_signature' => 'John Doe',
        'statement_of_truth_certified' => true,
        'form_number' => '26-4555',
        'veteran' => {
          'full_name' => { 'first' => 'John', 'last' => 'Doe' },
          'ssn' => '123-45-6789',
          'email' => 'john@example.com'
        },
        'living_situation' => {
          'is_in_care_facility' => true,
          'care_facility_name' => 'Test Facility'
        }
      }
    end
    let(:form) { described_class.new(form_data) }

    it 'returns complete payload structure' do
      payload = form.as_payload

      expect(payload[:remarks]).to eq('Test remarks')
      expect(payload[:otherConditions]).to eq('Test conditions')
      expect(payload[:statementOfTruthSignature]).to eq('John Doe')
      expect(payload[:statementOfTruthCertified]).to be true
      expect(payload[:formNumber]).to eq('26-4555')
      expect(payload).to have_key(:veteran)
      expect(payload).to have_key(:livingSituation)
      expect(payload).to have_key(:previousHiApplication)
      expect(payload).to have_key(:previousSahApplication)
      expect(payload[:livingSituation][:careFacilityName]).to eq('Test Facility')
      expect(payload[:livingSituation][:isInCareFacility]).to be true
      expect(payload[:livingSituation]).to have_key(:careFacilityAddress)
    end
  end

  describe '#living_situation_payload' do
    let(:form_data) do
      {
        'living_situation' => {
          'care_facility_name' => 'Test Facility',
          'is_in_care_facility' => true,
          'care_facility_address' => {
            'street' => '123 Care St',
            'city' => 'Care City',
            'country' => 'USA'
          }
        }
      }
    end
    let(:form) { described_class.new(form_data) }

    it 'includes country in development environment' do
      allow(Rails.env).to receive(:eql?).with('development').and_return(true)

      payload = form.send(:living_situation_payload)
      expect(payload[:careFacilityAddress][:country]).to eq('USA')
    end

    it 'excludes country in production environment' do
      allow(Rails.env).to receive(:eql?).with('development').and_return(false)
      allow(Settings).to receive(:vsp_environment).and_return('production')

      payload = form.send(:living_situation_payload)
      expect(payload[:careFacilityAddress]).not_to have_key(:country)
    end
  end
end
