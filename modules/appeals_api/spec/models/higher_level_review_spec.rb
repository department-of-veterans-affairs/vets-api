# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::HigherLevelReview, type: :model do
  include FixtureHelpers

  let(:higher_level_review) { default_higher_level_review }
  let(:default_higher_level_review) { create :higher_level_review, :status_received }
  let(:auth_headers) { default_auth_headers }
  let(:default_auth_headers) { fixture_as_json 'valid_200996_headers.json', version: 'v1' }
  let(:form_data) { default_form_data }
  let(:default_form_data) { fixture_as_json 'valid_200996.json', version: 'v1' }
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

  describe '#stamp_text' do
    it { expect(higher_level_review.stamp_text).to eq('Doe - 6789') }
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
    let(:higher_level_review) do
      described_class.new(form_data: form_data, auth_headers: auth_headers, api_version: api_version)
    end
    let(:api_version) { 'V1' }

    context 'when a veteran birth date is in the future' do
      let(:auth_headers) { default_auth_headers.merge 'X-VA-Birth-Date' => (Time.zone.today + 2).to_s }

      it 'creates an invalid record' do
        expect(higher_level_review.valid?).to be false
        expect(higher_level_review.errors.to_a.length).to eq 1
        expect(higher_level_review.errors.to_a.first.downcase).to include 'veteran'
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

      it 'creates an invalid record' do
        expect(higher_level_review.valid?).to be false
        expect(higher_level_review.errors.to_a.length).to eq 1
        expect(higher_level_review.errors.to_a.first.downcase).to include 'decisiondate'
        expect(higher_level_review.errors.to_a.first.downcase).to include 'past'
      end
    end

    describe 'V2' do
      let(:api_version) { 'V2' }
      let(:default_auth_headers) { fixture_as_json 'valid_200996_headers_extra.json', version: 'v2' }
      let(:default_form_data) { fixture_as_json 'valid_200996_extra.json', version: 'v2' }

      context 'when a claimant birth date is in the future' do
        let(:auth_headers) { default_auth_headers.merge 'X-VA-Claimant-Birth-Date' => (Time.zone.today + 2).to_s }

        it 'creates an invalid record' do
          expect(higher_level_review.valid?).to be false
          expect(higher_level_review.errors.to_a.length).to eq 1
          expect(higher_level_review.errors.to_a.first.downcase).to include 'claimant'
          expect(higher_level_review.errors.to_a.first.downcase).to include 'past'
        end
      end

      context 'claimant header & form_data requirements' do
        describe 'when headers are provided but form_data is missing' do
          let(:auth_headers) do
            default_auth_headers.except(*%w[X-VA-Claimant-First-Name X-VA-Claimant-Last-Name X-VA-Claimant-Birth-Date])
          end

          it 'creates and invalid record' do
            expect(higher_level_review.valid?).to be false
            expect(higher_level_review.errors.to_a.length).to eq 1
            expect(higher_level_review.errors.to_a.first.downcase).to include 'missing claimant headers'
          end
        end

        describe 'when claimant data is provided but missing headers' do
          let(:form_data) { default_form_data.tap { |fd| fd['data']['attributes'].delete('claimant') } }

          it 'creates and invalid record' do
            expect(higher_level_review.valid?).to be false
            expect(higher_level_review.errors.to_a.length).to eq 1
            expect(higher_level_review.errors.to_a.first.downcase).to include 'missing claimant data'
          end
        end

        describe 'when both claimant and form data are missing' do
          let(:auth_headers) do
            default_auth_headers.except(*%w[X-VA-Claimant-First-Name X-VA-Claimant-Last-Name X-VA-Claimant-Birth-Date])
          end
          let(:form_data) { default_form_data.tap { |fd| fd['data']['attributes'].delete('claimant') } }

          it 'creates a valid record' do
            expect(higher_level_review.valid?).to be true
          end
        end
      end
    end

    describe '#stamp_text' do
      it { expect(higher_level_review.stamp_text).to eq('Doe - 6789') }

      it 'truncates the last name if too long' do
        full_last_name = 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdddddddddd'
        auth_headers['X-VA-Last-Name'] = full_last_name
        expect(higher_level_review.stamp_text).to eq 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdd... - 6789'
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

    it 'does not emit event when to and from statuses are the same' do
      handler = instance_double(AppealsApi::Events::Handler)
      allow(AppealsApi::Events::Handler).to receive(:new).and_return(handler)
      allow(handler).to receive(:handle!)

      higher_level_review.update_status!(status: higher_level_review.status)

      expect(handler).not_to have_received(:handle!)
    end

    it 'successfully gets the ICN when email isn\'t present' do
      higher_level_review = described_class.create!(
        api_version: 'v1',
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
    let(:hlr_veteran_only) { create(:minimal_higher_level_review_v2) }

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

      it { expect(subject.class).to eq AppealsApi::Appellant }
    end

    describe '#veteran' do
      subject { higher_level_review_v2.veteran }

      it { expect(subject.class).to eq AppealsApi::Appellant }
    end

    context 'when veteran only data' do
      describe '#signing_appellant' do
        let(:appellant_type) { hlr_veteran_only.signing_appellant.send(:type) }

        it { expect(appellant_type).to eq :veteran }
      end

      describe '#appellant_local_time' do
        it do
          appellant_local_time = hlr_veteran_only.appellant_local_time
          created_at = hlr_veteran_only.created_at

          expect(appellant_local_time).to eq created_at.in_time_zone('America/Chicago')
        end
      end
    end

    context 'when veteran and claimant data' do
      describe '#signing_appellant' do
        let(:appellant_type) { higher_level_review_v2.signing_appellant.send(:type) }

        it { expect(appellant_type).to eq :claimant }
      end

      describe '#appellant_local_time' do
        it do
          appellant_local_time = higher_level_review_v2.appellant_local_time
          created_at = higher_level_review_v2.created_at

          expect(appellant_local_time).to eq created_at.in_time_zone('America/Chicago')
        end
      end
    end
  end

  context 'PdfOutputPrep concern' do
    let(:auth_headers) { fixture_as_json 'invalid_200996_headers_characters.json', version: 'v2' }
    let(:form_data) { fixture_as_json 'invalid_200996_characters.json', version: 'v2' }

    describe '#pdf_output_prep' do
      it 'clears memoized values' do
        expected = 'Smartquotes: “”‘’'
        expect(higher_level_review.contestable_issues[0].text).to eq 'tinnitus'
        higher_level_review.form_data['included'][0]['attributes']['issue'] = expected
        higher_level_review.pdf_output_prep
        expect(higher_level_review.contestable_issues[0].text).to eq expected
      end

      it 'removes characters that are incompatible with Windows-1252' do
        higher_level_review.form_data['included'][0]['attributes']['issue'] = '∑mer allergies'
        higher_level_review.pdf_output_prep
        expect(higher_level_review.contestable_issues[0].text).to eq 'mer allergies'
      end

      it 'maintains the original encoding of the value' do
        higher_level_review.form_data['included'][0]['attributes']['issue'].encode! 'US-ASCII'
        higher_level_review.form_data['included'][1]['attributes']['issue'].encode! 'ISO-8859-14'
        higher_level_review.pdf_output_prep
        expect(higher_level_review.contestable_issues[0].text.encoding.to_s).to eq 'US-ASCII'
        expect(higher_level_review.contestable_issues[1].text.encoding.to_s).to eq 'ISO-8859-14'
      end
    end
  end
end
