# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

shared_examples 'SC metadata' do |opts|
  let(:api_version) { opts[:api_version] }
  let(:sc) { create(opts[:factory], api_version:) }

  it 'saves evidence type to metadata' do
    expect(sc.metadata.dig('form_data', 'evidence_type')).to eq(%w[upload])
  end

  it 'saves benefit type to metadata' do
    expect(sc.metadata.dig('form_data', 'benefit_type')).to eq('fiduciary')
  end

  it 'saves the central mail business line to metadata' do
    expect(sc.metadata['central_mail_business_line']).to eq('FID')
  end

  describe 'write-in issue count' do
    context 'with only write-in issues' do
      it 'saves the correct value to metadata' do
        expect(sc.metadata['potential_write_in_issue_count']).to eq(1)
      end
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
      let(:sc) { create(opts[:factory], form_data:, api_version:) }

      it 'saves the correct value to metadata' do
        expect(sc.metadata['potential_write_in_issue_count']).to eq(2)
      end
    end
  end

  context 'when api_version is not V2 or V0' do
    let(:api_version) { 'V1' } # (does not exist)

    it 'assigns no metadata' do
      expect(sc.metadata).to eql({})
    end
  end
end

describe AppealsApi::SupplementalClaim, type: :model do
  include FixtureHelpers

  describe 'when api_version is v0' do
    let(:supplemental_claim) { create(:supplemental_claim_v0) }

    describe '#veteran_icn' do
      subject { supplemental_claim.veteran_icn }

      it 'matches the ICN in the form data' do
        expect(subject).to be_present
        expect(subject).to eq supplemental_claim.form_data.dig('data', 'attributes', 'veteran', 'icn')
      end
    end

    describe '#soc_opt_in' do
      describe 'by default' do
        subject { supplemental_claim.soc_opt_in }

        it('is true') { is_expected.to be(true) }
      end

      describe 'if a false value is provided' do
        subject do
          supplemental_claim.form_data['data']['attributes']['socOptIn'] = false
          supplemental_claim.soc_opt_in
        end

        it('ignores the user-provided value') { is_expected.to be(true) }
      end
    end

    describe 'metadata' do
      include_examples 'SC metadata',
                       api_version: 'V0',
                       factory: :supplemental_claim_v0,
                       extra_factory: :extra_supplemental_claim_v0,
                       form_data_fixture: 'supplemental_claims/v0/valid_200995.json'
    end

    describe 'validations' do
      let(:appeal) { build(:extra_supplemental_claim_v0, api_version: 'V0') }

      it_behaves_like 'shared model validations', {
        validations: %i[veteran_birth_date_is_in_the_past
                        claimant_birth_date_is_in_the_past
                        contestable_issue_dates_are_in_the_past
                        country_codes_valid],
        required_claimant_headers: []
      }
    end
  end

  describe 'when api_version is v2' do
    let(:default_auth_headers) { fixture_as_json 'decision_reviews/v2/valid_200995_headers.json' }
    let(:default_form_data) { fixture_as_json 'decision_reviews/v2/valid_200995.json' }

    let(:supplemental_claim_veteran_only) { create(:supplemental_claim) }
    let(:sc_with_nvc) { create(:extra_supplemental_claim) }

    it_behaves_like 'an appeal model with updatable status' do
      let(:example_instance) { supplemental_claim_veteran_only }
      let(:instance_without_email) do
        described_class.create!(
          auth_headers: default_auth_headers,
          api_version: 'V2',
          form_data: default_form_data.deep_merge(
            { 'data' => { 'attributes' => { 'veteran' => { 'email' => nil } } } }
          )
        )
      end
    end

    describe 'metadata' do
      include_examples 'SC metadata',
                       api_version: 'V2',
                       factory: :minimal_supplemental_claim,
                       extra_factory: :extra_supplemental_claim,
                       form_data_fixture: 'decision_reviews/v2/valid_200995.json'
    end

    describe '#veteran_icn' do
      subject { sc.veteran_icn }

      let(:sc) { create(:supplemental_claim) }

      it 'matches header' do
        expect(subject).to be_present
        expect(subject).to eq sc.auth_headers['X-VA-ICN']
      end

      describe 'when ICN not provided in header' do
        let(:sc) { create(:supplemental_claim, auth_headers: default_auth_headers.except('X-VA-ICN')) }

        it 'is blank' do
          expect(subject).to be_blank
        end
      end
    end

    describe 'validations' do
      let(:appeal) { build(:extra_supplemental_claim) }

      it_behaves_like 'shared model validations', {
        validations: %i[veteran_birth_date_is_in_the_past
                        contestable_issue_dates_are_in_the_past
                        required_claimant_data_is_present],
        required_claimant_headers: described_class.required_nvc_headers
      }

      context "when 'claimant' fields provided by 'claimantType' is 'veteran'" do
        it 'errors with pointer to claimant type attribute' do
          appeal.form_data['data']['attributes']['claimantType'] = 'veteran'

          expect(appeal.valid?).to be false
          expect(appeal.errors.size).to eq 1
          error = appeal.errors.first
          expect(error.attribute).to eq(:'/data/attributes/claimantType')
          expect(error.message).to eq "If '/data/attributes/claimant' field is supplied, " \
                                      "'data/attributes/claimantType' must not be 'veteran'"
        end
      end

      context "when 'evidenceSubmission' fields have invalid date ranges under 'retrieveFrom'" do
        it 'errors with a point to the offending evidenceDates index' do
          retrieve_from = appeal.form_data['data']['attributes']['evidenceSubmission']['retrieveFrom']
          retrieve_from[2]['attributes']['evidenceDates'][0]['startDate'] = '2020-05-10'

          expect(appeal.valid?).to be false
          expect(appeal.errors.size).to eq 1
          error = appeal.errors.first
          expect(error.attribute)
            .to eq(:'/data/attributes/evidenceSubmission/retrieveFrom[2]/attributes/evidenceDates[0]')
          expect(error.message).to eq '2020-05-10 must before or the same day as 2020-04-10. ' \
                                      'Both dates must also be in the past.'
        end
      end

      context "when 'evidenceSubmission.retrieveFrom.endDate' is in the future" do
        it 'errors with a point to the offending evidenceDates index' do
          retrieve_from = appeal.form_data['data']['attributes']['evidenceSubmission']['retrieveFrom']
          end_date = (Time.zone.today + 1.day).to_s
          retrieve_from[2]['attributes']['evidenceDates'][0]['endDate'] = end_date

          expect(appeal.valid?).to be false
          expect(appeal.errors.size).to eq 1
          error = appeal.errors.first
          expect(error.attribute)
            .to eq(:'/data/attributes/evidenceSubmission/retrieveFrom[2]/attributes/evidenceDates[0]')
          expect(error.message).to eq "2020-04-10 must before or the same day as #{end_date}. " \
                                      'Both dates must also be in the past.'
        end
      end

      context "when 'evidenceSubmission.retrieveFrom.endDate' is same as submission date" do
        it 'does not errort' do
          retrieve_from = appeal.form_data['data']['attributes']['evidenceSubmission']['retrieveFrom']
          end_date = Time.zone.today.to_s
          retrieve_from[2]['attributes']['evidenceDates'][0]['endDate'] = end_date

          expect(appeal.valid?).to be true
          expect(appeal.errors.size).to eq 0
        end
      end
    end

    describe '#veteran_dob_month' do
      it { expect(sc_with_nvc.veteran_dob_month).to eq '12' }
    end

    describe '#veteran_dob_day' do
      it { expect(sc_with_nvc.veteran_dob_day).to eq '31' }
    end

    describe '#veteran_dob_year' do
      it { expect(sc_with_nvc.veteran_dob_year).to eq '1969' }
    end

    describe '#consumer_name' do
      it { expect(sc_with_nvc.consumer_name).to eq 'va.gov' }
    end

    describe '#consumer_id' do
      it { expect(sc_with_nvc.consumer_id).to eq 'some-guid' }
    end

    describe '#benefit_type' do
      it { expect(sc_with_nvc.benefit_type).to eq 'compensation' }
    end

    describe '#claimant_type' do
      it { expect(sc_with_nvc.claimant_type).to eq 'other' }
    end

    describe '#claimant_type_other_text' do
      it { expect(sc_with_nvc.claimant_type_other_text).to eq 'Veteran Attorney' }
    end

    describe '#contestable_issues' do
      subject { sc_with_nvc.contestable_issues.to_json }

      it 'matches json' do
        form_data = sc_with_nvc.form_data
        issues = form_data['included'].map { |issue| AppealsApi::ContestableIssue.new(issue) }.to_json

        expect(subject).to eq(issues)
      end
    end

    describe '#evidence_submission_days_window' do
      it { expect(sc_with_nvc.evidence_submission_days_window).to eq 7 }
    end

    describe '#accepts_evidence?' do
      it { expect(sc_with_nvc.accepts_evidence?).to be true }
    end

    describe '#outside_submission_window_error' do
      error = {
        title: 'unprocessable_entity',
        detail: 'This submission is outside of the 7-day window for evidence submission',
        code: 'OutsideSubmissionWindow',
        status: '422'
      }

      it { expect(sc_with_nvc.outside_submission_window_error).to eq error }
    end

    describe '#soc_opt_in' do
      let(:sc_opted_in) { create(:extra_supplemental_claim) }
      let(:sc_not_opted_in) { create(:minimal_supplemental_claim) }

      describe 'when pdf version is unset' do
        it 'uses the value from the record' do
          expect(sc_opted_in.soc_opt_in).to be true
          expect(sc_not_opted_in.soc_opt_in).to be false
        end
      end

      describe 'when pdf_version is v2' do
        let(:sc_opted_in) { create(:extra_supplemental_claim, pdf_version: 'v2') }
        let(:sc_not_opted_in) { create(:minimal_supplemental_claim, pdf_version: 'v2') }

        it 'uses the value from the record' do
          expect(sc_opted_in.soc_opt_in).to be true
          expect(sc_not_opted_in.soc_opt_in).to be false
        end
      end

      describe 'when pdf_version is v3' do
        let(:sc_opted_in) { create(:extra_supplemental_claim, pdf_version: 'v3') }
        let(:sc_not_opted_in) { create(:minimal_supplemental_claim, pdf_version: 'v3') }

        it 'is always true' do
          expect(sc_opted_in.soc_opt_in).to be true
          expect(sc_not_opted_in.soc_opt_in).to be true
        end
      end
    end

    describe '#form_5103_notice_acknowledged' do
      it { expect(sc_with_nvc.form_5103_notice_acknowledged).to be true }
    end

    describe '#date_signed' do
      subject { sc_with_nvc.date_signed }

      it('matches json') do
        expected = Time.now.in_time_zone(sc_with_nvc.signing_appellant.timezone).strftime('%m/%d/%Y')
        expect(subject).to eq(expected)
      end
    end

    describe '#stamp_text' do
      let(:default_auth_headers) { fixture_as_json 'decision_reviews/v2/valid_200995_headers.json' }
      let(:form_data) { fixture_as_json 'decision_reviews/v2/valid_200995.json' }

      it { expect(sc_with_nvc.stamp_text).to eq 'Doé - 6789' }

      it 'truncates the last name if too long' do
        full_last_name = 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdddddddddd'
        default_auth_headers['X-VA-Last-Name'] = full_last_name

        sc = AppealsApi::SupplementalClaim.new(auth_headers: default_auth_headers, form_data:)

        expect(sc.stamp_text).to eq 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdd... - 6789'
      end
    end

    describe '#evidence_type' do
      it { expect(sc_with_nvc.evidence_type).to eq %w[upload retrieval] }
    end

    describe '#lob' do
      it { expect(sc_with_nvc.lob).to eq 'CMP' }
    end

    describe '#submit_evidence_to_central_mail!' do
      let(:supplemental_claim) { create(:supplemental_claim) }
      let(:evidence_submission1) { create(:evidence_submission, supportable: supplemental_claim) }
      let(:evidence_submission2) { create(:evidence_submission, supportable: supplemental_claim) }
      let(:evidence_submissions) { [evidence_submission1, evidence_submission2] }

      before do
        allow(supplemental_claim).to receive(:evidence_submissions).and_return(evidence_submissions)
        allow(evidence_submission1).to receive(:submit_to_central_mail!)
        allow(evidence_submission2).to receive(:submit_to_central_mail!)
      end

      it 'calls "#submit_to_central_mail!" for each evidence submission' do
        supplemental_claim.submit_evidence_to_central_mail!

        expect(evidence_submission1).to have_received(:submit_to_central_mail!)
        expect(evidence_submission2).to have_received(:submit_to_central_mail!)
      end
    end

    context 'appellant handling' do
      describe '#veteran' do
        subject { sc_with_nvc.veteran }

        it { expect(subject.class).to eq AppealsApi::Appellant }
      end

      describe '#claimant' do
        subject { sc_with_nvc.claimant }

        it { expect(subject.class).to eq AppealsApi::Appellant }
      end

      context 'when veteran only data' do
        describe '#signing_appellant' do
          let(:appellant_type) { supplemental_claim_veteran_only.signing_appellant.send(:type) }

          it { expect(appellant_type).to eq :veteran }
        end

        describe '#appellant_local_time' do
          it do
            appellant_local_time = supplemental_claim_veteran_only.appellant_local_time
            created_at = supplemental_claim_veteran_only.created_at

            expect(appellant_local_time).to eq created_at.in_time_zone('America/Chicago')
          end
        end

        describe '#full_name' do
          it { expect(supplemental_claim_veteran_only.full_name).to eq 'Jäñe ø Doé' }
        end

        describe '#signing_appellant_zip_code' do
          it { expect(supplemental_claim_veteran_only.signing_appellant_zip_code).to eq '30012' }
        end
      end

      context 'when veteran and claimant data' do
        describe '#signing_appellant' do
          let(:appellant_type) { sc_with_nvc.signing_appellant.send(:type) }

          it { expect(appellant_type).to eq :claimant }
        end

        describe '#appellant_local_time' do
          it do
            appellant_local_time = sc_with_nvc.appellant_local_time
            created_at = sc_with_nvc.created_at

            expect(appellant_local_time).to eq created_at.in_time_zone('America/Detroit')
          end
        end

        describe '#full_name' do
          it { expect(sc_with_nvc.full_name).to eq 'joe b smart' }
        end

        describe '#signing_appellant_zip_code' do
          it { expect(sc_with_nvc.signing_appellant_zip_code).to eq '00000' }
        end
      end

      describe '#stamp_text' do
        let(:supplemental_claim) { build(:supplemental_claim) }

        it { expect(supplemental_claim.stamp_text).to eq('Doé - 6789') }

        it 'truncates the last name if too long' do
          full_last_name = 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdddddddddd'
          supplemental_claim.auth_headers['X-VA-Last-Name'] = full_last_name
          expect(supplemental_claim.stamp_text).to eq 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdd... - 6789'
        end
      end
    end
  end

  describe 'callbacks' do
    describe 'before_update' do
      before { allow(supplemental_claim).to receive(:submit_evidence_to_central_mail!) }

      context 'when the status has changed to "complete"' do
        let(:supplemental_claim) { create(:supplemental_claim, status: 'processing') }

        context 'and the delay evidence feature is enabled' do
          before { Flipper.enable(:decision_review_delay_evidence) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

          it 'calls "#submit_evidence_to_central_mail!"' do
            supplemental_claim.update(status: 'complete')

            expect(supplemental_claim).to have_received(:submit_evidence_to_central_mail!)
          end
        end

        context 'and the delay evidence feature is disabled' do
          before { Flipper.disable(:decision_review_delay_evidence) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

          it 'does not call "#submit_evidence_to_central_mail!"' do
            supplemental_claim.update(status: 'complete')

            expect(supplemental_claim).not_to have_received(:submit_evidence_to_central_mail!)
          end
        end
      end

      context 'when the status has not changed' do
        let(:supplemental_claim) { create(:supplemental_claim, status: 'success') }

        context 'and the delay evidence feature is enabled' do
          before { Flipper.enable(:decision_review_delay_evidence) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

          it 'does not call "#submit_evidence_to_central_mail!"' do
            supplemental_claim.update(source: 'VA.gov')

            expect(supplemental_claim).not_to have_received(:submit_evidence_to_central_mail!)
          end
        end
      end

      context 'when the status has changed but not to "success"' do
        let(:supplemental_claim) { create(:supplemental_claim, status: 'submitted') }

        context 'and the delay evidence feature is enabled' do
          before { Flipper.enable(:decision_review_delay_evidence) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

          it 'does not call "submit_evidence_to_central_mail!"' do
            supplemental_claim.update(status: 'processing')

            expect(supplemental_claim).not_to have_received(:submit_evidence_to_central_mail!)
          end
        end
      end
    end
  end
end
