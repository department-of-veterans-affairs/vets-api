# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::HigherLevelReview, type: :model do
  include FixtureHelpers

  let(:higher_level_review) { default_higher_level_review }
  let(:default_higher_level_review) { create :higher_level_review, :status_received }
  let(:auth_headers) { default_auth_headers }
  let(:default_auth_headers) { fixture_as_json 'valid_200996_headers.json' }
  let(:form_data) { default_form_data }
  let(:default_form_data) { fixture_as_json 'valid_200996.json' }
  let(:form_data_attributes) { form_data.dig('data', 'attributes') }

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

  describe '#zip_code_5' do
    subject { higher_level_review.zip_code_5 }

    it('matches json') { is_expected.to eq form_data_attributes.dig('veteran', 'address', 'zipCode5').to_s }
  end

  describe '#veteran_phone_number' do
    subject { higher_level_review.veteran_phone_number }

    it('matches json') { is_expected.to eq '+34-555-800-1111 ex2' }
  end

  describe '#email' do
    subject { higher_level_review.email }

    it('matches json') { is_expected.to eq form_data_attributes['veteran']['emailAddressText'] }
  end

  describe '#benefit_type' do
    subject { higher_level_review.benefit_type }

    it('matches json') { is_expected.to eq form_data_attributes['benefitType'] }
  end

  describe '#same_office' do
    subject { higher_level_review.same_office }

    it('matches json') { is_expected.to eq form_data_attributes['sameOffice'] }
  end

  describe '#informal_conference' do
    subject { higher_level_review.informal_conference }

    it('matches json') { is_expected.to eq form_data_attributes['informalConference'] }
  end

  describe '#informal_conference_times' do
    subject { higher_level_review.informal_conference_times }

    it('matches json') { is_expected.to eq form_data_attributes['informalConferenceTimes'] }
  end

  describe '#contestable_issues' do
    subject { higher_level_review.contestable_issues.to_json }

    it 'matches json' do
      issues = form_data['included'].map { |issue| AppealsApi::ContestableIssue.new(issue) }.to_json

      expect(subject).to eq(issues)
    end
  end

  describe '#date_signed' do
    subject { higher_level_review.date_signed }

    it('matches json') do
      expect(subject).to eq(
        Time.now.in_time_zone(form_data_attributes['veteran']['timezone']).strftime('%m/%d/%Y')
      )
    end
  end

  context 'validations' do
    let(:higher_level_review) { described_class.new(form_data: form_data, auth_headers: auth_headers) }

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
              'type' => 'contestableIssue',
              'attributes' => {
                'issue' => 'tinnitus',
                'decisionDate' => 'banana'
              }
            },
            {
              'type' => 'contestableIssue',
              'attributes' => {
                'issue' => 'PTSD',
                'decisionDate' => (Time.zone.today + 2).to_s
              }
            },
            {
              'type' => 'contestableIssue',
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

  describe '#update_status!' do
    it 'error status' do
      higher_level_review.update_status!(status: 'error', code: 'code', detail: 'detail')

      expect(higher_level_review.status).to eq('error')
      expect(higher_level_review.code).to eq('code')
      expect(higher_level_review.detail).to eq('detail')
    end

    it 'other valid status' do
      higher_level_review.update_status!(status: 'success')

      expect(higher_level_review.status).to eq('success')
    end

    it 'invalid status' do
      expect do
        higher_level_review.update_status!(status: 'invalid_status')
      end.to raise_error(ActiveRecord::RecordInvalid,
                         'Validation failed: Status is not included in the list')
    end

    it 'emits an event' do
      handler = instance_double(AppealsApi::Events::Handler)
      allow(AppealsApi::Events::Handler).to receive(:new).and_return(handler)
      allow(handler).to receive(:handle!)

      higher_level_review.update_status!(status: 'pending')

      expect(handler).to have_received(:handle!)
    end

    it 'successfully gets the ICN when email isn\'t present' do
      higher_level_review = described_class.create!(
        auth_headers: auth_headers,
        form_data: default_form_data.deep_merge({
                                                  'data' => {
                                                    'attributes' => {
                                                      'veteran' => {
                                                        'emailAddressText' => nil
                                                      }
                                                    }
                                                  }
                                                })
      )

      params = { event_type: :hlr_received, opts: {
        email_identifier: { id_value: '1013062086V794840', id_type: 'ICN' },
        first_name: higher_level_review.first_name,
        date_submitted: higher_level_review.date_signed,
        guid: higher_level_review.id
      } }

      stub_mpi

      handler = instance_double(AppealsApi::Events::Handler)
      allow(AppealsApi::Events::Handler).to receive(:new).and_call_original
      allow(AppealsApi::Events::Handler).to receive(:new).with(params).and_return(handler)
      allow(handler).to receive(:handle!)

      higher_level_review.update_status!(status: 'submitted')

      expect(AppealsApi::Events::Handler).to have_received(:new).exactly(2).times
    end
  end

  describe 'V2' do
    let(:higher_level_review_v2) { create :extra_higher_level_review_v2 }

    describe '#number_and_street' do
      subject { higher_level_review_v2.number_and_street }

      it { expect(subject).to eq('123 Main St Suite #1200 Box 4') }
    end

    describe '#city' do
      subject { higher_level_review_v2.city }

      it { expect(subject).to eq('New York') }
    end

    describe '#state_code' do
      subject { higher_level_review_v2.state_code }

      it { expect(subject).to eq('NY') }
    end

    describe '#country_code' do
      subject { higher_level_review_v2.country_code }

      it { expect(subject).to eq('US') }
    end

    describe '#zip_code_5' do
      subject { higher_level_review_v2.zip_code_5 }

      it { expect(subject).to eq('30012') }
    end

    describe '#claimant' do
      subject { higher_level_review_v2.claimant }

      it do
        expect(subject.class).to eq(AppealsApi::NonVeteranClaimant)
      end

      it 'returns nil if claimant first and last names are not present in headers' do
        hlr_no_claimant_headers = higher_level_review
        higher_level_review.auth_headers.merge('X-VA-Claimant-Middle-Initial' => 'D')

        expect(hlr_no_claimant_headers.claimant).to eq nil
      end
    end
  end
end
