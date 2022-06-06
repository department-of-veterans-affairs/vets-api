# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::SupplementalClaim, type: :model do
  include FixtureHelpers

  let(:default_auth_headers) { fixture_as_json 'valid_200995_headers.json', version: 'v2' }
  let(:default_form_data) { fixture_as_json 'valid_200995.json', version: 'v2' }

  let(:supplemental_claim_veteran_only) { create(:supplemental_claim) }
  let(:sc_with_nvc) { create(:extra_supplemental_claim) }

  describe 'validations' do
    let(:appeal) { build(:extra_supplemental_claim) }

    it_behaves_like 'shared model validations', validations: %i[birth_date_is_in_the_past
                                                                contestable_issue_dates_are_in_the_past
                                                                required_claimant_data_is_present],
                                                required_claimant_headers: described_class.required_nvc_headers
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
      detail: 'This submission is outside of the 7-day window for evidence submission.',
      code: 'OutsideSubmissionWindow',
      status: '422'
    }

    it { expect(sc_with_nvc.outside_submission_window_error).to eq error }
  end

  describe '#soc_opt_in' do
    it { expect(sc_with_nvc.soc_opt_in).to be true }
  end

  describe '#form_5103_notice_acknowledged' do
    it { expect(sc_with_nvc.form_5103_notice_acknowledged).to be true }
  end

  describe '#date_signed' do
    subject { sc_with_nvc.date_signed }

    it('matches json') do
      expect(subject).to eq(
        Time.now.in_time_zone(sc_with_nvc.signing_appellant.timezone).strftime('%m/%d/%Y')
      )
    end
  end

  describe '#stamp_text' do
    let(:default_auth_headers) { fixture_as_json 'valid_200995_headers.json', version: 'v2' }
    let(:form_data) { fixture_as_json 'valid_200995.json', version: 'v2' }

    it { expect(sc_with_nvc.stamp_text).to eq 'Doé - 6789' }

    it 'truncates the last name if too long' do
      full_last_name = 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdddddddddd'
      default_auth_headers['X-VA-Last-Name'] = full_last_name

      sc = AppealsApi::SupplementalClaim.new(auth_headers: default_auth_headers, form_data: form_data)

      expect(sc.stamp_text).to eq 'AAAAAAAAAAbbbbbbbbbbCCCCCCCCCCdd... - 6789'
    end
  end

  describe '#update_status!' do
    let(:supplemental_claim) { create(:supplemental_claim) }

    it 'handles the error statues with code and detail' do
      supplemental_claim.update_status!(status: 'error', code: 'code', detail: 'detail')

      expect(supplemental_claim.status).to eq('error')
      expect(supplemental_claim.code).to eq('code')
      expect(supplemental_claim.detail).to eq('detail')
    end

    it 'updates the appeal with a valid status' do
      supplemental_claim.update_status!(status: 'success')

      expect(supplemental_claim.status).to eq('success')
    end

    it 'raises and error if status is invalid' do
      expect do
        sc_with_nvc.update_status!(status: 'invalid_status')
      end.to raise_error(ActiveRecord::RecordInvalid,
                         'Validation failed: Status is not included in the list')
    end

    it 'emits events with expected values' do
      Timecop.freeze(Time.zone.now) do
        sc_with_nvc.update_status!(status: 'submitted')

        expect(AppealsApi::EventsWorker.jobs.size).to eq(2)

        status_event = AppealsApi::EventsWorker.jobs.first
        expect(status_event['args']).to eq([
                                             'sc_status_updated',
                                             {
                                               'from' => 'pending',
                                               'to' => 'submitted',
                                               'status_update_time' => Time.zone.now.iso8601,
                                               'statusable_id' => sc_with_nvc.id
                                             }
                                           ])

        email_event = AppealsApi::EventsWorker.jobs.last
        expect(email_event['args']).to eq([
                                            'sc_received',
                                            {
                                              'email_identifier' => {
                                                'id_type' => 'email',
                                                'id_value' => 'joe@email.com'
                                              },
                                              'first_name' => 'Jäñe',
                                              'date_submitted' =>
                                                sc_with_nvc.created_at.in_time_zone('America/Detroit').iso8601,
                                              'guid' => sc_with_nvc.id,
                                              'claimant_email' => 'joe@email.com',
                                              'claimant_first_name' => 'joe'
                                            }
                                          ])
      end
    end

    it 'successfully gets the ICN when email isn\'t present' do
      sc_with_nvc = described_class.create!(
        auth_headers: default_auth_headers,
        api_version: 'V2',
        form_data: default_form_data.deep_merge({
                                                  'data' => {
                                                    'attributes' => {
                                                      'veteran' => {
                                                        'email' => nil
                                                      }
                                                    }
                                                  }
                                                })
      )

      params = { event_type: :sc_received, opts: {
        email_identifier: { id_value: '1013062086V794840', id_type: 'ICN' },
        first_name: sc_with_nvc.veteran.first_name,
        date_submitted: sc_with_nvc.created_at.in_time_zone('America/Chicago').iso8601,
        guid: sc_with_nvc.id
      } }

      stub_mpi

      handler = instance_double(AppealsApi::Events::Handler)
      allow(AppealsApi::Events::Handler).to receive(:new).and_call_original
      allow(AppealsApi::Events::Handler).to receive(:new).with(params).and_return(handler)
      allow(handler).to receive(:handle!)

      sc_with_nvc.update_status!(status: 'submitted')

      expect(AppealsApi::Events::Handler).to have_received(:new).exactly(2).times
    end

    context 'when PII is removed' do
      before do
        sc_with_nvc.update_columns form_data_ciphertext: nil, auth_headers_ciphertext: nil # rubocop:disable Rails/SkipsModelValidations
        sc_with_nvc.reload
      end

      it 'successfully emits status update event, skips email event' do
        Timecop.freeze(Time.current) do
          sc_with_nvc.update_status!(status: 'submitted')

          expect(AppealsApi::EventsWorker.jobs.count).to eq 1
          status_event = AppealsApi::EventsWorker.jobs.first
          expect(status_event['args']).to eq([
                                               'sc_status_updated',
                                               {
                                                 'from' => 'pending',
                                                 'to' => 'submitted',
                                                 'status_update_time' => Time.zone.now.iso8601,
                                                 'statusable_id' => sc_with_nvc.id
                                               }
                                             ])
        end
      end
    end
  end

  describe '#lob' do
    it { expect(sc_with_nvc.lob).to eq 'CMP' }
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

    context 'non-veteran claimant validations' do
      let(:sc_with_nvc_built) { build(:extra_supplemental_claim) }
      let(:auth_headers) { sc_with_nvc_built.auth_headers }
      let(:form_data) { sc_with_nvc_built.form_data }

      context 'claimant header & form_data requirements' do
        describe 'when claimant data is provided but claimant headers are missing' do
          it 'is invalid with error detailing the missing required claimant headers' do
            auth_headers.except!(*%w[X-VA-Claimant-First-Name X-VA-Claimant-Middle-Initial X-VA-Claimant-Last-Name])

            expect(sc_with_nvc_built.valid?).to be false
            expect(sc_with_nvc_built.errors.size).to eq 1
            error = sc_with_nvc_built.errors.first
            expect(error.message).to include 'missing claimant headers'
            expect(error.options[:meta]).to match_array({ missing_fields: %w[X-VA-Claimant-First-Name
                                                                             X-VA-Claimant-Last-Name] })
          end
        end

        describe 'when claimant headers are provided but missing claimant data' do
          it 'is not a valid record' do
            form_data.tap { |fd| fd['data']['attributes'].delete('claimant') }

            expect(sc_with_nvc_built.valid?).to be false
            expect(sc_with_nvc_built.errors.size).to eq 1
            expect(sc_with_nvc_built.errors.first.message).to include 'headers were provided but missing'
          end
        end

        describe 'when both claimant and form data are missing' do
          let(:minimal_sc) { create(:minimal_supplemental_claim) }

          it 'creates a valid record' do
            expect(minimal_sc.valid?).to be true
          end
        end
      end
    end
  end
end
