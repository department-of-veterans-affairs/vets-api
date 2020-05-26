# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::HigherLevelReview, type: :model do
  include FixtureHelpers

  let(:higher_level_review) { default_higher_level_review }
  let(:default_higher_level_review) { create :higher_level_review }
  let(:auth_headers) { default_auth_headers }
  let(:default_auth_headers) { fixture_as_json 'valid_200996_headers.json' }
  let(:form_data) { default_form_data }
  let(:default_form_data) { fixture_as_json 'valid_200996.json' }

  describe '#first_name' do
    subject { higher_level_review.first_name }

    it('matches header') { is_expected.to eq auth_headers['X-VA-First-Name'] }
  end

  describe '#middle_initial' do
    subject { higher_level_review.middle_initial }

    it('matches header') { is_expected.to eq auth_headers['X-VA-Middle-Initial'] }
  end

  describe '#last_name' do
    subject { higher_level_review.last_name }

    it('matches header') { is_expected.to eq auth_headers['X-VA-Last-Name'] }
  end

  describe '#full_name' do
    subject { higher_level_review.full_name }

    it 'matches header' do
      expect(subject).to eq(
        "#{auth_headers['X-VA-First-Name']} #{auth_headers['X-VA-Middle-Initial']}" \
        " #{auth_headers['X-VA-Last-Name']}"
      )
    end

    context 'not all name fields used' do
      let(:higher_level_review) { described_class.new(form_data: form_data, auth_headers: auth_headers) }

      context 'only last name' do
        let(:auth_headers) { default_auth_headers.except('X-VA-Middle-Initial').merge('X-VA-First-Name' => ' ') }

        it 'just last name with no extra spaces' do
          expect(subject).to eq auth_headers['X-VA-Last-Name']
        end
      end

      context 'no middle initial' do
        context 'blank' do
          let(:auth_headers) { default_auth_headers.merge 'X-VA-Middle-Initial' => ' ' }

          it 'one space between first and last name' do
            expect(subject).to eq "#{auth_headers['X-VA-First-Name']} #{auth_headers['X-VA-Last-Name']}"
          end
        end

        context 'nil' do
          let(:auth_headers) { default_auth_headers.except 'X-VA-Middle-Initial' }

          it 'one space between first and last name' do
            expect(subject).to eq "#{auth_headers['X-VA-First-Name']} #{auth_headers['X-VA-Last-Name']}"
          end
        end
      end
    end
  end

  describe '#ssn' do
    subject { higher_level_review.ssn }

    it('matches header') { is_expected.to eq auth_headers['X-VA-SSN'] }
  end

  describe '#file_number' do
    subject { higher_level_review.file_number }

    it('matches header') { is_expected.to eq auth_headers['X-VA-File-Number'] }
  end

  describe '#birth_mm' do
    subject { higher_level_review.birth_mm }

    it('matches header') { is_expected.to eq auth_headers['X-VA-Birth-Date'][5..6] }
  end

  describe '#birth_dd' do
    subject { higher_level_review.birth_dd }

    it('matches header') { is_expected.to eq auth_headers['X-VA-Birth-Date'][8..9] }
  end

  describe '#birth_yyyy' do
    subject { higher_level_review.birth_yyyy }

    it('matches header') { is_expected.to eq auth_headers['X-VA-Birth-Date'][0..3] }
  end

  describe '#service_number' do
    subject { higher_level_review.service_number }

    it('matches header') { is_expected.to eq auth_headers['X-VA-Service-Number'] }
  end

  describe '#insurance_policy_number' do
    subject { higher_level_review.insurance_policy_number }

    it('matches header') { is_expected.to eq auth_headers['X-VA-Insurance-Policy-Number'] }
  end

  describe '#number_and_street' do
    subject { higher_level_review.number_and_street }

    it('matches json') do
      expect(subject).to eq form_data.dig('data', 'attributes', 'veteran', 'address', 'addressLine1').to_s
    end
  end

  describe '#apt_unit_number' do
    subject { higher_level_review.apt_unit_number }

    it('matches json') do
      expect(subject).to eq form_data.dig('data', 'attributes', 'veteran', 'address', 'addressLine2').to_s
    end
  end

  describe '#city' do
    subject { higher_level_review.city }

    it('matches json') { is_expected.to eq form_data.dig('data', 'attributes', 'veteran', 'address', 'cityName').to_s }
  end

  describe '#state_code' do
    subject { higher_level_review.state_code }

    it('matches json') { is_expected.to eq form_data.dig('data', 'attributes', 'veteran', 'address', 'stateCode').to_s }
  end

  describe '#country_code' do
    subject { higher_level_review.country_code }

    it('matches json') do
      expect(subject).to eq form_data.dig('data', 'attributes', 'veteran', 'address', 'countryCodeISO2').to_s
    end
  end

  describe '#zip_code_5' do
    subject { higher_level_review.zip_code_5 }

    it('matches json') { is_expected.to eq form_data.dig('data', 'attributes', 'veteran', 'address', 'zipCode5').to_s }
  end

  describe '#zip_code_4' do
    subject { higher_level_review.zip_code_4 }

    it('matches json') { is_expected.to eq form_data.dig('data', 'attributes', 'veteran', 'address', 'zipCode4').to_s }
  end

  describe '#veteran_phone_number' do
    subject { higher_level_review.veteran_phone_number }

    it('matches json') { is_expected.to eq '+34-555-800-1111 ex2' }
  end

  describe '#email' do
    subject { higher_level_review.email }

    it('matches json') { is_expected.to eq form_data['data']['attributes']['veteran']['emailAddressText'] }
  end

  describe '#benefit_type' do
    subject { higher_level_review.benefit_type }

    it('matches json') { is_expected.to eq form_data['data']['attributes']['benefitType'] }
  end

  describe '#same_office?' do
    subject { higher_level_review.same_office? }

    it('matches json') { is_expected.to eq form_data['data']['attributes']['sameOffice'] }
  end

  describe '#informal_conference?' do
    subject { higher_level_review.informal_conference? }

    it('matches json') { is_expected.to eq form_data['data']['attributes']['informalConference'] }
  end

  describe '#informal_conference_times' do
    subject { higher_level_review.informal_conference_times }

    it('matches json') { is_expected.to eq form_data['data']['attributes']['informalConferenceTimes'] }
  end

  describe '#informal_conference_rep_name_and_phone_number' do
    subject { higher_level_review.informal_conference_rep_name_and_phone_number }

    it('matches json') do
      expect(subject).to eq(
        form_data['data']['attributes']['informalConferenceRep']['name'] +
        ' +' +
        form_data['data']['attributes']['informalConferenceRep']['phone']['countryCode'] +
        '-' +
        form_data['data']['attributes']['informalConferenceRep']['phone']['areaCode'] +
        '-' +
        form_data['data']['attributes']['informalConferenceRep']['phone']['phoneNumber'][0..2] +
        '-' +
        form_data['data']['attributes']['informalConferenceRep']['phone']['phoneNumber'][3..] +
        ' ext' +
        form_data['data']['attributes']['informalConferenceRep']['phone']['phoneNumberExt']
      )
    end
  end

  describe '#contestable_issues' do
    subject { higher_level_review.contestable_issues }

    it('matches json') { is_expected.to eq form_data['included'] }
  end

  describe '#date_signed' do
    subject { higher_level_review.date_signed }

    it('matches json') do
      expect(subject).to eq(
        Time.now.in_time_zone(form_data['data']['attributes']['veteran']['timezone']).strftime('%m/%d/%Y')
      )
    end
  end

  context 'validations' do
    let(:higher_level_review) { described_class.new(form_data: form_data, auth_headers: auth_headers) }

    context 'veteran phone number is too long' do
      let(:form_data) do
        {
          'data' => {
            'type' => default_form_data['data']['type'],
            'attributes' => default_form_data['data']['attributes'].merge(veteran)
          },
          'included' => default_form_data['included']
        }
      end

      let(:veteran) do
        {
          veteran: {
            phone: { areaCode: '999', phoneNumber: '1234567890', phoneNumberExt: '1234567890' }
          }
        }.as_json
      end

      it 'a phone number that\'s too long creates an invalid record (b/c won\'t fit on the form)' do
        expect(higher_level_review.valid?).to be false
        expect(higher_level_review.errors.to_a.length).to eq 1
        expect(higher_level_review.errors.to_a.first.downcase).to include 'phone'
      end
    end

    context 'informal conference rep info is too long' do
      let(:form_data) do
        {
          'data' => {
            'type' => default_form_data['data']['type'],
            'attributes' => default_form_data['data']['attributes'].merge(informal_conference_rep)
          },
          'included' => default_form_data['included']
        }
      end

      let(:informal_conference_rep) do
        {
          'informalConferenceRep' => {
            'name' => 'x' * 1000,
            'phone' => default_form_data['data']['attributes']['informalConferenceRep']['phone']
          }
        }
      end

      it 'too much informal conference info creates an invalid record (b/c won\'t fit on the form)' do
        expect(higher_level_review.valid?).to be false
        expect(higher_level_review.errors.to_a.length).to eq 1
        expect(higher_level_review.errors.to_a.first.downcase).to include 'rep'
      end
    end

    context 'birth date isn\'t a date' do
      let(:auth_headers) { default_auth_headers.merge 'X-VA-Birth-Date' => 'apricot' }

      it 'using a birth date that isn\'t a date creates an invalid record' do
        expect(higher_level_review.valid?).to be false
        expect(higher_level_review.errors.to_a.length).to eq 1
        expect(higher_level_review.errors.to_a.first.downcase).to include 'isn\'t a date'
      end
    end

    context 'birth date isn\'t in the past' do
      let(:auth_headers) { default_auth_headers.merge 'X-VA-Birth-Date' => (Time.zone.today + 2).to_s }

      it 'using a birth date /not/ in the past creates an invalid record' do
        expect(higher_level_review.valid?).to be false
        expect(higher_level_review.errors.to_a.length).to eq 1
        expect(higher_level_review.errors.to_a.first.downcase).to include 'past'
      end
    end

    context 'bad contestable issue dates' do
      let(:form_data) do
        {
          'data' => default_form_data['data'],
          'included' => [
            {
              'type' => 'ContestableIssue',
              'attributes' => {
                'issue' => 'tinnitus',
                'decisionDate' => 'banana'
              }
            },
            {
              'type' => 'ContestableIssue',
              'attributes' => {
                'issue' => 'PTSD',
                'decisionDate' => (Time.zone.today + 2).to_s
              }
            },
            {
              'type' => 'ContestableIssue',
              'attributes' => {
                'issue' => 'right knee',
                'decisionDate' => '1901-01-31'
              }
            }
          ]
        }
      end

      it 'bad decision dates will create an invalid record' do
        expect(higher_level_review.valid?).to be false
        expect(higher_level_review.errors.to_a.length).to eq 2
        expect(higher_level_review.errors.to_a.first).to include 'decisionDate'
        expect(higher_level_review.errors.to_a.second).to include 'decisionDate'
      end
    end
  end

  describe 'removing persisted data' do
    it 'removed the persisted data when success status reached' do
      received_hlr = FactoryBot.create(:higher_level_review, :status_received)
      received_hlr.status = 'success'
      received_hlr.save
      received_hlr.reload
      expect(received_hlr.form_data).to be_nil
      expect(received_hlr.auth_headers).to be_nil
    end

    it 'removed the persisted data when error status reached' do
      received_hlr = FactoryBot.create(:higher_level_review, :status_received)
      received_hlr.status = 'error'
      received_hlr.save
      received_hlr.reload
      expect(received_hlr.form_data).to be_nil
    end
  end
end
