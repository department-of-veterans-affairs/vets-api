# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::HigherLevelReview, type: :model do
  include FixtureHelpers

  let(:higher_level_review) { create :higher_level_review }
  let(:auth_headers) { fixture_as_json 'valid_200996_headers.json' }
  let(:form_data) { fixture_as_json 'valid_200996.json' }

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

    it('matches json') { is_expected.to eq form_data['data']['attributes']['veteran']['address']['addressLine1'] }
  end

  describe '#apt_unit_number' do
    subject { higher_level_review.apt_unit_number }

    it('matches json') { is_expected.to eq form_data['data']['attributes']['veteran']['address']['addressLine2'] }
  end

  describe '#city' do
    subject { higher_level_review.city }

    it('matches json') { is_expected.to eq form_data['data']['attributes']['veteran']['address']['cityName'] }
  end

  describe '#state_code' do
    subject { higher_level_review.state_code }

    it('matches json') { is_expected.to eq form_data['data']['attributes']['veteran']['address']['stateCode'] }
  end

  describe '#country_code' do
    subject { higher_level_review.country_code }

    it('matches json') { is_expected.to eq form_data['data']['attributes']['veteran']['address']['countryCodeISO2'] }
  end

  describe '#zip_code_5' do
    subject { higher_level_review.zip_code_5 }

    it('matches json') { is_expected.to eq form_data['data']['attributes']['veteran']['address']['zipCode5'] }
  end

  describe '#zip_code_4' do
    subject { higher_level_review.zip_code_4 }

    it('matches json') { is_expected.to eq form_data['data']['attributes']['veteran']['address']['zipCode4'] }
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
end
