# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::HigherLevelReview, type: :model do
  include FixtureHelpers

  shared_examples 'HLR metadata' do |opts|
    let(:hlr) { create(opts[:factory]) }

    it 'saves central_mail_business_line to metadata' do
      expect(hlr.metadata['central_mail_business_line']).to eq('FID')
    end

    it 'save benefit_type to metadata' do
      expect(hlr.metadata['form_data']['benefit_type']).to eq('fiduciary')
    end

    describe 'non-veteran claimant flag' do
      it 'saves non-veteran claimant status to metadata' do
        expect(hlr.metadata['non_veteran_claimant']).to eq(false)
      end

      describe 'with non-veteran claimant' do
        let(:hlr) { create(opts[:extra_factory]) }

        it 'saves non-veteran claimant status to metadata' do
          expect(hlr.metadata['non_veteran_claimant']).to eq(true)
        end
      end
    end

    describe 'potential_write_in_issue_count' do
      it 'saves the correct value to metadata' do
        expect(hlr.metadata['potential_write_in_issue_count']).to eq(3)
      end

      context 'with mixed write-in and non-write-in issues' do
        let(:form_data) do
          data = fixture_as_json(opts[:form_data_fixture])
          data['included'].push(
            {
              'type' => 'appealableIssue',
              'attributes' => {
                'issue' => 'issue text with ID', 'decisionDate' => '1999-09-09', 'ratingIssueReferenceId' => '2'
              }
            },
            {
              'type' => 'appealableIssue',
              'attributes' => { 'issue' => 'write-in issue text', 'decisionDate' => '2000-02-02' }
            }
          )
          data
        end
        let(:sc) { create(opts[:factory], form_data:) }

        it 'saves the correct value to metadata' do
          expect(sc.metadata['potential_write_in_issue_count']).to eq(4)
        end
      end
    end
  end

  shared_examples 'HLR record attributes from delegators' do |opts|
    let(:higher_level_review) { create(opts[:factory], status: 'pending') }

    describe '#first_name' do
      subject { higher_level_review.first_name }

      it { is_expected.to eq higher_level_review.veteran.first_name }
    end

    describe '#middle_initial' do
      subject { higher_level_review.middle_initial }

      it { is_expected.to eq higher_level_review.veteran.middle_initial }
    end

    describe '#last_name' do
      subject { higher_level_review.last_name }

      it { is_expected.to eq higher_level_review.veteran.last_name }
    end

    describe '#ssn' do
      subject { higher_level_review.ssn }

      it { is_expected.to eq higher_level_review.veteran.ssn }
    end

    describe '#file_number' do
      subject { higher_level_review.file_number }

      it { is_expected.to eq higher_level_review.veteran.file_number }
    end

    describe '#veteran_birth_mm' do
      subject { higher_level_review.veteran_birth_mm }

      it { is_expected.to eq higher_level_review.veteran.birth_date.strftime('%m') }
    end

    describe '#veteran_birth_dd' do
      subject { higher_level_review.veteran_birth_dd }

      it { is_expected.to eq higher_level_review.veteran.birth_date.strftime('%d') }
    end

    describe '#veteran_birth_yyyy' do
      subject { higher_level_review.veteran_birth_yyyy }

      it { is_expected.to eq higher_level_review.veteran.birth_date.strftime('%Y') }
    end

    describe '#service_number' do
      subject { higher_level_review.service_number }

      it { is_expected.to eq higher_level_review.veteran.service_number }
    end

    describe '#insurance_policy_number' do
      subject { higher_level_review.insurance_policy_number }

      it { is_expected.to eq higher_level_review.veteran.insurance_policy_number }
    end
  end

  describe 'when api_version is v0' do
    let(:higher_level_review) { create(:higher_level_review_v0, status: 'pending') }

    include_examples 'HLR record attributes from delegators', factory: :higher_level_review_v0

    include_examples 'HLR metadata',
                     factory: :higher_level_review_v0,
                     extra_factory: :extra_higher_level_review_v0,
                     form_data_fixture: 'higher_level_reviews/v0/valid_200996.json'

    describe '#veteran_icn' do
      subject { higher_level_review.veteran_icn }

      it 'matches the ICN in the form data' do
        expect(subject).to be_present
        expect(subject).to eq higher_level_review.form_data.dig('data', 'attributes', 'veteran', 'icn')
      end
    end

    describe '#soc_opt_in' do
      describe 'by default' do
        subject { higher_level_review.soc_opt_in }

        it('is true') { is_expected.to eq true }
      end

      describe 'if a false value is provided' do
        subject do
          form_data = fixture_as_json('higher_level_reviews/v0/valid_200996.json')
          form_data['data']['attributes']['socOptIn'] = false

          hlr = create(:higher_level_review_v0, form_data:)
          hlr.soc_opt_in
        end

        it('ignores the user-provided value') { is_expected.to eq true }
      end
    end

    describe 'validations' do
      let(:appeal) do
        described_class.new(form_data:, auth_headers:, api_version: 'V0')
      end
      let(:auth_headers) { fixture_as_json 'higher_level_reviews/v0/valid_200996_headers.json' }
      let(:form_data) { fixture_as_json 'higher_level_reviews/v0/valid_200996_extra.json' }

      it_behaves_like 'shared model validations', {
        validations: %i[veteran_birth_date_is_in_the_past
                        contestable_issue_dates_are_in_the_past
                        claimant_birth_date_is_in_the_past
                        country_codes_valid],
        required_claimant_headers: described_class.required_nvc_headers
      }
    end
  end

  describe 'when api_version is v2' do
    let(:default_higher_level_review) { create :higher_level_review_v2, status: 'pending' }
    let(:default_auth_headers) { fixture_as_json 'decision_reviews/v2/valid_200996_headers.json' }
    let(:default_form_data) { fixture_as_json 'decision_reviews/v2/valid_200996.json' }
    let(:higher_level_review) { default_higher_level_review }
    let(:auth_headers) { default_auth_headers }
    let(:form_data) { default_form_data }
    let(:form_data_attributes) { form_data.dig('data', 'attributes') }

    include_examples 'HLR record attributes from delegators', factory: :higher_level_review_v2

    include_examples 'HLR metadata',
                     factory: :higher_level_review_v2,
                     extra_factory: :extra_higher_level_review_v2,
                     form_data_fixture: 'decision_reviews/v2/valid_200996.json'

    describe '#veteran_icn' do
      subject { higher_level_review.veteran_icn }

      it 'matches header' do
        expect(subject).to be_present
        expect(subject).to eq higher_level_review.auth_headers['X-VA-ICN']
      end

      describe 'when ICN not provided in header' do
        let(:higher_level_review) do
          create(:higher_level_review_v2, auth_headers: default_auth_headers.except('X-VA-ICN'))
        end

        it 'is blank' do
          expect(subject).to be_blank
        end
      end
    end

    describe '#full_name' do
      subject { higher_level_review.full_name }

      it 'matches header' do
        expected_name = auth_headers.slice('X-VA-First-Name', 'X-VA-Middle-Initial', 'X-VA-Last-Name').values.join(' ')
        expect(subject).to eq expected_name
      end

      context 'not all name fields used' do
        let(:higher_level_review) { described_class.new(form_data:, auth_headers:) }

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
      it { expect(higher_level_review.stamp_text).to eq('Doé - 6789') }

      describe 'when the last name is too long' do
        let(:higher_level_review) do
          auth_headers = default_auth_headers.merge!('X-VA-Last-Name' => 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdddddddddd')
          create(:higher_level_review_v2, auth_headers:)
        end

        it 'truncates the last name' do
          expect(higher_level_review.stamp_text).to eq 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdd... - 6789'
        end
      end
    end

    describe '#zip_code_5' do
      subject { higher_level_review.zip_code_5 }

      it('matches json') { is_expected.to eq form_data_attributes.dig('veteran', 'address', 'zipCode5').to_s }
    end

    describe '#veteran_phone_number' do
      subject { higher_level_review.veteran_phone_number }

      before do
        data = higher_level_review.form_data
        phone_data = data.dig(*%w[data attributes veteran phone])
        phone_data['countryCode'] = '34'
        phone_data['phoneNumberExt'] = '2'
        higher_level_review.form_data = data
      end

      it('matches json') { is_expected.to eq '+34-555-800-1111 ex2' }
    end

    describe '#email' do
      subject { higher_level_review.email }

      it('matches json') { is_expected.to eq form_data_attributes['veteran']['email'] }
    end

    describe '#benefit_type' do
      subject { higher_level_review.benefit_type }

      it('matches json') { is_expected.to eq form_data_attributes['benefitType'] }
    end

    describe '#metadata_formdata_benefit_type' do
      subject { higher_level_review.metadata['form_data']['benefit_type'] }

      it('matches json') { is_expected.to eq form_data_attributes['benefitType'] }
    end

    describe '#metadata_central_mail_business_line' do
      subject { higher_level_review.metadata['central_mail_business_line'] }

      it('matches json') { is_expected.to eq higher_level_review.lob }
    end

    describe '#informal_conference' do
      subject { higher_level_review.informal_conference }

      it('matches json') { is_expected.to eq form_data_attributes['informalConference'] }
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
        expected_date = Time.now.in_time_zone(form_data_attributes['veteran']['timezone']).strftime('%m/%d/%Y')
        expect(subject).to eq(expected_date)
      end
    end

    describe 'status updates' do
      it_behaves_like 'an appeal model with updatable status' do
        let(:example_instance) { higher_level_review }
        let(:instance_without_email) do
          described_class.create!(
            auth_headers:,
            api_version: 'V2',
            form_data: form_data.deep_merge(
              { 'data' => { 'attributes' => { 'veteran' => { 'email' => nil } } } }
            )
          )
        end
      end
    end

    context 'validations' do
      # V1 has been deprecated, so no need to check validations of records we've effectively archived
      let(:appeal) do # appeal is used here since the shared example expects it
        described_class.new(form_data:, auth_headers:, api_version: 'V2')
      end
      let(:auth_headers) { fixture_as_json 'decision_reviews/v2/valid_200996_headers_extra.json' }
      let(:form_data) { fixture_as_json 'decision_reviews/v2/valid_200996_extra.json' }

      it_behaves_like 'shared model validations', {
        validations: %i[veteran_birth_date_is_in_the_past
                        contestable_issue_dates_are_in_the_past
                        required_claimant_data_is_present
                        claimant_birth_date_is_in_the_past
                        country_codes_valid],
        required_claimant_headers: described_class.required_nvc_headers
      }
    end

    describe 'attributes' do
      let(:higher_level_review_v2) { create(:extra_higher_level_review_v2) }
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

      describe '#soc_opt_in' do
        let(:hlr_opted_in) { create(:higher_level_review_v2) }
        let(:not_opted_in_form_data) do
          form_data['data']['attributes']['socOptIn'] = false
          form_data
        end
        let(:hlr_not_opted_in) { create(:higher_level_review_v2, form_data: not_opted_in_form_data) }

        describe 'when pdf version is unset' do
          it 'uses the value from the record' do
            expect(hlr_opted_in.soc_opt_in).to eq(true)
            expect(hlr_not_opted_in.soc_opt_in).to eq(false)
          end
        end

        describe 'when pdf_version is v2' do
          let(:hlr_opted_in) { create(:higher_level_review_v2, pdf_version: 'v2') }
          let(:hlr_not_opted_in) do
            create(:higher_level_review_v2, form_data: not_opted_in_form_data, pdf_version: 'v2')
          end

          it 'uses the value from the record' do
            expect(hlr_opted_in.soc_opt_in).to be true
            expect(hlr_not_opted_in.soc_opt_in).to be false
          end
        end

        describe 'when pdf_version is v3' do
          let(:hlr_opted_in) { create(:higher_level_review_v2, pdf_version: 'v3') }
          let(:hlr_not_opted_in) do
            create(:higher_level_review_v2, form_data: not_opted_in_form_data, pdf_version: 'v3')
          end

          it 'is always true' do
            expect(hlr_opted_in.soc_opt_in).to be true
            expect(hlr_not_opted_in.soc_opt_in).to be true
          end
        end
      end
    end

    context 'PdfOutputPrep concern' do
      let(:auth_headers) { fixture_as_json 'decision_reviews/v2/invalid_200996_headers_characters.json' }
      let(:form_data) { fixture_as_json 'decision_reviews/v2/invalid_200996_characters.json' }

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

  context 'HlrStatus concern' do
    let(:hlr_v1) { create(:higher_level_review_v1) }
    let(:hlr_v2) { create(:higher_level_review_v2) }
    let(:hlr_v0) { create(:higher_level_review_v0) }

    describe '#versioned_statuses' do
      it 'returns the V1 statuses for V1 HLR records' do
        expect(hlr_v1.versioned_statuses).to match_array(AppealsApi::HlrStatus::V1_STATUSES)
      end

      it 'returns the V2 statuses for V2 HLR records' do
        expect(hlr_v2.versioned_statuses).to match_array(AppealsApi::HlrStatus::V2_STATUSES)
      end

      it 'returns the V0 statuses for V0 HLR records' do
        expect(hlr_v0.versioned_statuses).to match_array(AppealsApi::HlrStatus::V0_STATUSES)
      end
    end
  end
end
