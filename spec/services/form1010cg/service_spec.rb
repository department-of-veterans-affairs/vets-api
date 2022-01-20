# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/form1010cg_helpers/build_claim_data_for'

RSpec.describe Form1010cg::Service do
  include Form1010cgHelpers

  let(:subject) { described_class.new build(:caregivers_assistance_claim) }
  let(:default_email_on_mvi_search) { 'no-email@example.com' }

  describe '::auditor' do
    it 'is an instance of Form1010cg::Auditor' do
      expect(described_class::AUDITOR).to be_an_instance_of(Form1010cg::Auditor)
    end

    it 'is using Rails.logger' do
      expect(described_class::AUDITOR.logger).to eq(Rails.logger)
    end
  end

  describe '::new' do
    it 'requires a claim' do
      expect { described_class.new }.to raise_error do |e|
        expect(e).to be_a(ArgumentError)
        expect(e.message).to eq('wrong number of arguments (given 0, expected 1..2)')
      end
    end

    it 'raises error if claim is invalid' do
      expect { described_class.new(SavedClaim::CaregiversAssistanceClaim.new(form: '{}')) }.to raise_error do |e|
        expect(e).to be_a(Common::Exceptions::ValidationErrors)
        expect(e.errors.size).to eq(2)
        expect(e.errors[0].code).to eq('100')
        expect(e.errors[0].detail).to include("did not contain a required property of 'veteran'")
        expect(e.errors[0].status).to eq('422')
        expect(e.errors[1].detail).to include("did not contain a required property of 'primaryCaregiver'")
        expect(e.errors[1].status).to eq('422')
        expect(e.errors[1].code).to eq('100')
      end
    end

    it 'sets claim' do
      claim = build(:caregivers_assistance_claim)
      service = described_class.new claim

      expect(service.claim).to eq(claim)
    end

    describe 'flipper toggle for mulesoft' do
      let(:claim) { build(:caregivers_assistance_claim) }
      let(:service) { described_class.new(claim) }

      before do
        allow(Flipper).to receive(:enabled?).with(:caregiver_mulesoft).and_return(cfg_val)
      end

      context 'is true' do
        let(:cfg_val) { true }

        it 'gets a mulesoft client' do
          expect(service.send(:carma_client)).to be_an_instance_of(CARMA::Client::MuleSoftClient)
        end
      end

      context 'is false' do
        let(:cfg_val) { false }

        it 'gets a salesforce client' do
          expect(service.send(:carma_client)).to be_an_instance_of(CARMA::Client::Client)
        end
      end
    end
  end

  describe '::collect_attachments' do
    let(:claim_pdf_path) { 'tmp/10-10cg-application.pdf' }
    let(:poa_attachment_path) { 'tmp/poa_file.jpg' }

    before do
      expect(claim).to receive(:to_pdf).with(sign: true).and_return(claim_pdf_path)
    end

    context 'when "poaAttachmentId" is not provided on claim' do
      let(:claim) { build(:caregivers_assistance_claim) }

      it 'returns the claim pdf path only' do
        expect(
          described_class.collect_attachments(claim)
        ).to eq(
          [claim_pdf_path, nil]
        )
      end
    end

    context 'when "poaAttachmentId" is provided on claim' do
      let(:poa_attachment_guid) { 'cdbaedd7-e268-49ed-b714-ec543fbb1fb8' }
      let(:form_data)           { build_claim_data { |d| d['poaAttachmentId'] = poa_attachment_guid }.to_json }
      let(:claim)               { build(:caregivers_assistance_claim, form: form_data) }

      context 'when the Form1010cg::Attachment is not found' do
        it 'returns the claim pdf path only' do
          expect(
            described_class.collect_attachments(claim)
          ).to eq(
            [claim_pdf_path, nil]
          )
        end
      end

      context 'when the Form1010cg::Attachment is found' do
        let(:attachment) { build(:form1010cg_attachment, guid: poa_attachment_guid) }
        let(:vcr_options) do
          {
            record: :none,
            allow_unused_http_interactions: false,
            match_requests_on: %i[method host body]
          }
        end

        before do
          VCR.use_cassette("s3/object/put/#{poa_attachment_guid}/doctors-note_jpg", vcr_options) do
            attachment.set_file_data!(
              Rack::Test::UploadedFile.new(
                Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.jpg'),
                'image/jpg'
              )
            )
          end

          attachment.save!
          expect_any_instance_of(attachment.class).to receive(:to_local_file).and_return(poa_attachment_path)
        end

        after do
          Form1010cg::Attachment.delete_all
        end

        it 'returns the claim pdf path and attachment path' do
          expect(
            described_class.collect_attachments(claim)
          ).to eq(
            [claim_pdf_path, poa_attachment_path]
          )
        end
      end
    end
  end

  describe '::submit_attachments!' do
    let(:carma_case_id) { 'CAS_1234' }
    let(:veteran_name) { { 'first' => 'Jane', 'last' => 'Doe' } }
    let(:claim_pdf_path) { 'tmp/10-10cg-application.pdf' }
    let(:poa_attachment_path) { 'tmp/poa_file.jpg' }

    it 'requires carma_case_id, veteran_name, claim_pdf_path' do
      expect { described_class.submit_attachments! }.to raise_error(ArgumentError) do |e|
        expect(e.message).to eq('wrong number of arguments (given 0, expected 3..4)')
      end

      expect { described_class.submit_attachments!(carma_case_id) }.to raise_error(ArgumentError) do |e|
        expect(e.message).to eq('wrong number of arguments (given 1, expected 3..4)')
      end

      expect { described_class.submit_attachments!(carma_case_id, veteran_name) }.to raise_error(ArgumentError) do |e|
        expect(e.message).to eq('wrong number of arguments (given 2, expected 3..4)')
      end
    end

    context 'when veteran_name is invalid' do
      it 'raises error' do
        expect { described_class.submit_attachments!(carma_case_id, nil, claim_pdf_path) }.to raise_error(
          'invalid veteran_name'
        )

        expect { described_class.submit_attachments!(carma_case_id, {}, claim_pdf_path) }.to raise_error(
          'invalid veteran_name'
        )

        arguments = [carma_case_id, { 'fullName' => {} }, claim_pdf_path]
        expect { described_class.submit_attachments!(*arguments) }.to raise_error(
          'invalid veteran_name'
        )
      end
    end

    context 'with valid paramaters' do
      let(:carma_attachments) { double }

      before do
        expect(CARMA::Models::Attachments).to receive(:new).with(
          carma_case_id, veteran_name['first'], veteran_name['last']
        ).and_return(carma_attachments)
      end

      context 'with claim PDF only' do
        before do
          expect(carma_attachments).to receive(:add).with('10-10CG', claim_pdf_path).and_return(carma_attachments)
          expect(carma_attachments).to receive(:submit!).and_return(:PROCESSED_ATTACHMENTS)
        end

        it 'submits the documents to carma' do
          expect(
            described_class.submit_attachments!(carma_case_id, veteran_name, claim_pdf_path)
          ).to eq(:PROCESSED_ATTACHMENTS)
        end
      end

      context 'with claim PDF and POA attachment' do
        before do
          expect(carma_attachments).to receive(:add).with('10-10CG', claim_pdf_path).and_return(carma_attachments)
          expect(carma_attachments).to receive(:add).with('POA', poa_attachment_path).and_return(carma_attachments)
          expect(carma_attachments).to receive(:submit!).and_return(:PROCESSED_ATTACHMENTS)
        end

        it 'submits the documents to carma' do
          expect(
            described_class.submit_attachments!(carma_case_id, veteran_name, claim_pdf_path, poa_attachment_path)
          ).to eq(:PROCESSED_ATTACHMENTS)
        end
      end
    end
  end

  describe '#icn_for' do
    let(:set_ssn) { ->(data, _form_subject) { data['ssnOrTin'] = '111111111' } }

    it 'searches MVI for the provided form subject' do
      subject = described_class.new(
        build(
          :caregivers_assistance_claim,
          form: {
            'veteran' => build_claim_data_for(:veteran),
            'primaryCaregiver' => build_claim_data_for(:primaryCaregiver)
          }.to_json
        )
      )

      veteran_data = subject.claim.veteran_data

      expected_mvi_search_params = {
        first_name: veteran_data['fullName']['first'],
        middle_name: veteran_data['fullName']['middle'],
        last_name: veteran_data['fullName']['last'],
        birth_date: veteran_data['dateOfBirth'],
        gender: veteran_data['gender'],
        ssn: veteran_data['ssnOrTin'],
        email: default_email_on_mvi_search,
        uuid: be_an_instance_of(String),
        loa: {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      }

      expect(UserIdentity).to receive(:new).with(
        expected_mvi_search_params
      ).and_return(
        :user_identity
      )

      expect_any_instance_of(MPI::Service).to receive(:find_profile).with(
        :user_identity
      ).and_return(
        double(status: 'OK', profile: double(icn: :ICN_123))
      )

      result = subject.icn_for('veteran')

      expect(result).to eq(:ICN_123)
    end

    it 'returns "NOT_FOUND" when profile not found in MVI' do
      subject = described_class.new(
        build(
          :caregivers_assistance_claim,
          form: {
            'veteran' => build_claim_data_for(:veteran),
            'primaryCaregiver' => build_claim_data_for(:primaryCaregiver)
          }.to_json
        )
      )

      veteran_data = subject.claim.veteran_data

      expected_mvi_search_params = {
        first_name: veteran_data['fullName']['first'],
        middle_name: veteran_data['fullName']['middle'],
        last_name: veteran_data['fullName']['last'],
        birth_date: veteran_data['dateOfBirth'],
        gender: veteran_data['gender'],
        ssn: veteran_data['ssnOrTin'],
        email: default_email_on_mvi_search,
        uuid: be_an_instance_of(String),
        loa: {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      }

      expect(UserIdentity).to receive(:new).with(
        expected_mvi_search_params
      ).and_return(
        :user_identity
      )

      expect_any_instance_of(MPI::Service).to receive(:find_profile).with(
        :user_identity
      ).and_return(
        double(status: 'NOT_FOUND', error: double)
      )

      result = subject.icn_for('veteran')

      expect(result).to eq('NOT_FOUND')
    end

    it 'returns "NOT_FOUND" when no SSN is present' do
      subject = described_class.new(
        build(
          :caregivers_assistance_claim,
          form: {
            'veteran' => build_claim_data_for(:veteran),
            'primaryCaregiver' => build_claim_data_for(:primaryCaregiver)
          }.to_json
        )
      )

      # This should skip the MPI search and not build a UserIdentity
      expect(UserIdentity).not_to receive(:new)
      expect_any_instance_of(MPI::Service).not_to receive(:find_profile)

      result = subject.icn_for('primaryCaregiver')

      expect(result).to eq('NOT_FOUND')
    end

    it 'returns a cached responses when called more than once for a given subject' do
      subject = described_class.new(
        build(
          :caregivers_assistance_claim,
          form: {
            'veteran' => build_claim_data_for(:veteran),
            'primaryCaregiver' => build_claim_data_for(:primaryCaregiver, &set_ssn),
            'secondaryCaregiverOne' => build_claim_data_for(:secondaryCaregiverOne)
          }.to_json
        )
      )

      veteran_data = subject.claim.veteran_data
      pc_data = subject.claim.primary_caregiver_data

      expected_mvi_search_params = {
        veteran: {
          first_name: veteran_data['fullName']['first'],
          middle_name: veteran_data['fullName']['middle'],
          last_name: veteran_data['fullName']['last'],
          birth_date: veteran_data['dateOfBirth'],
          gender: veteran_data['gender'],
          ssn: veteran_data['ssnOrTin'],
          email: default_email_on_mvi_search,
          uuid: be_an_instance_of(String),
          loa: {
            current: LOA::THREE,
            highest: LOA::THREE
          }
        },
        primaryCaregiver: {
          first_name: pc_data['fullName']['first'],
          middle_name: pc_data['fullName']['middle'],
          last_name: pc_data['fullName']['last'],
          birth_date: pc_data['dateOfBirth'],
          gender: pc_data['gender'],
          ssn: pc_data['ssnOrTin'],
          email: default_email_on_mvi_search,
          uuid: be_an_instance_of(String),
          loa: {
            current: LOA::THREE,
            highest: LOA::THREE
          }
        }
      }

      expect(UserIdentity).to receive(:new).with(
        expected_mvi_search_params[:veteran]
      ).and_return(
        :veteran_user_identity
      )

      expect_any_instance_of(MPI::Service).to receive(:find_profile).with(
        :veteran_user_identity
      ).and_return(
        double(status: 'OK', profile: double(icn: :CACHED_VALUE))
      )

      expect(UserIdentity).to receive(:new).with(
        expected_mvi_search_params[:primaryCaregiver]
      ).and_return(
        :pc_user_identity
      )

      expect_any_instance_of(MPI::Service).to receive(:find_profile).with(
        :pc_user_identity
      ).and_return(
        double(status: 'NOT_FOUND', error: double)
      )

      3.times do
        expect(subject.icn_for('veteran')).to eq(:CACHED_VALUE)
      end

      3.times do
        expect(subject.icn_for('primaryCaregiver')).to eq('NOT_FOUND')
      end

      3.times do
        expect(subject.icn_for('secondaryCaregiverOne')).to eq('NOT_FOUND')
      end
    end

    context 'when email is provided' do
      it 'will provid that email in the mvi search' do
        veteran_email = 'veteran-email@example.com'
        veteran_data = build_claim_data_for(:veteran) do |data|
          data['email'] = veteran_email
        end

        subject = described_class.new(
          build(
            :caregivers_assistance_claim,
            form: {
              'veteran' => veteran_data,
              'primaryCaregiver' => build_claim_data_for(:primaryCaregiver)
            }.to_json
          )
        )

        expected_mvi_search_params = {
          first_name: veteran_data['fullName']['first'],
          middle_name: veteran_data['fullName']['middle'],
          last_name: veteran_data['fullName']['last'],
          birth_date: veteran_data['dateOfBirth'],
          gender: veteran_data['gender'],
          ssn: veteran_data['ssnOrTin'],
          email: veteran_email,
          uuid: be_an_instance_of(String),
          loa: {
            current: LOA::THREE,
            highest: LOA::THREE
          }
        }

        expect(UserIdentity).to receive(:new).with(
          expected_mvi_search_params
        ).and_return(
          :user_identity
        )

        expect_any_instance_of(MPI::Service).to receive(:find_profile).with(
          :user_identity
        ).and_return(
          double(status: 'OK', profile: double(icn: :ICN_123))
        )

        result = subject.icn_for('veteran')

        expect(result).to eq(:ICN_123)
      end
    end

    describe 'logging' do
      let(:subject) do
        described_class.new(
          build(
            :caregivers_assistance_claim,
            form: {
              'veteran' => build_claim_data_for(:veteran),
              'primaryCaregiver' => build_claim_data_for(:primaryCaregiver, &set_ssn),
              'secondaryCaregiverOne' => build_claim_data_for(:secondaryCaregiverOne, &set_ssn),
              'secondaryCaregiverTwo' => build_claim_data_for(:secondaryCaregiverTwo, &set_ssn)
            }.to_json
          )
        )
      end

      it 'will log the result of a successful search' do
        %w[veteran primaryCaregiver secondaryCaregiverOne secondaryCaregiverTwo].each do |form_subject|
          expect_any_instance_of(MPI::Service).to receive(:find_profile).and_return(
            double(status: 'OK', profile: double(icn: :ICN_123))
          )

          expect(described_class::AUDITOR).to receive(:log_mpi_search_result).with(
            claim_guid: subject.claim.guid,
            form_subject: form_subject,
            result: :found
          )

          subject.icn_for(form_subject)
        end
      end

      it 'will log the result of a unsuccessful search' do
        %w[veteran primaryCaregiver secondaryCaregiverOne secondaryCaregiverTwo].each do |form_subject|
          expect_any_instance_of(MPI::Service).to receive(:find_profile).and_return(
            double(status: 'NOT_FOUND', error: double)
          )

          expect(described_class::AUDITOR).to receive(:log_mpi_search_result).with(
            claim_guid: subject.claim.guid,
            form_subject: form_subject,
            result: :not_found
          )

          subject.icn_for(form_subject)
        end
      end

      it 'will log when a search is skipped' do
        subject = described_class.new(
          build(
            :caregivers_assistance_claim,
            form: {
              # Form subjects with no SSNs
              'veteran' => build_claim_data_for(:veteran),
              'primaryCaregiver' => build_claim_data_for(:primaryCaregiver),
              'secondaryCaregiverOne' => build_claim_data_for(:secondaryCaregiverOne),
              'secondaryCaregiverTwo' => build_claim_data_for(:secondaryCaregiverTwo)
            }.to_json
          )
        )

        # Only testing for caregivers, since veteran requires an SSN
        %w[primaryCaregiver secondaryCaregiverOne secondaryCaregiverTwo].each do |form_subject|
          expect(described_class::AUDITOR).to receive(:log_mpi_search_result).with(
            claim_guid: subject.claim.guid,
            form_subject: form_subject,
            result: :skipped
          )

          subject.icn_for(form_subject)
        end
      end

      it 'will not log the search result when reading from cache' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile).and_return(
          double(status: 'OK', profile: double(icn: :ICN_123))
        )

        # Exception would be raised if this is called more (or less than) than one time
        expect(described_class::AUDITOR).to receive(:log_mpi_search_result).with(
          claim_guid: subject.claim.guid,
          form_subject: 'veteran',
          result: :found
        )

        5.times do
          subject.icn_for('veteran')
        end
      end
    end
  end

  describe '#is_veteran' do
    it 'returns false if the icn for the for the subject is "NOT_FOUND"' do
      subject = described_class.new(
        build(
          :caregivers_assistance_claim,
          form: {
            'veteran' => build_claim_data_for(:veteran),
            'primaryCaregiver' => build_claim_data_for(:primaryCaregiver)
          }.to_json
        )
      )

      expect(subject).to receive(:icn_for).with('veteran').and_return('NOT_FOUND')
      expect_any_instance_of(EMIS::VeteranStatusService).not_to receive(:get_veteran_status)

      expect(subject.is_veteran('veteran')).to eq(false)
    end

    describe 'searches eMIS and' do
      context 'when title38_status_code is "V1"' do
        it 'returns true' do
          subject = described_class.new(
            build(
              :caregivers_assistance_claim,
              form: {
                'veteran' => build_claim_data_for(:veteran),
                'primaryCaregiver' => build_claim_data_for(:primaryCaregiver)
              }.to_json
            )
          )

          expected_icn = :ICN_123
          emis_response = double(
            error?: false,
            items: [
              double(
                title38_status_code: 'V1'
              )
            ]
          )

          expect(subject).to receive(:icn_for).with('veteran').and_return(expected_icn)
          expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status).with(
            icn: expected_icn
          ).and_return(
            emis_response
          )

          expect(subject.is_veteran('veteran')).to eq(true)
        end
      end

      context 'when title38_status_code is not "V1"' do
        it 'returns false' do
          subject = described_class.new(
            build(
              :caregivers_assistance_claim,
              form: {
                'veteran' => build_claim_data_for(:veteran),
                'primaryCaregiver' => build_claim_data_for(:primaryCaregiver)
              }.to_json
            )
          )

          expected_icn = :ICN_123
          emis_response = double(
            error?: false,
            items: [
              double(
                title38_status_code: 'V4'
              )
            ]
          )

          expect(subject).to receive(:icn_for).with('veteran').and_return(expected_icn)
          expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status).with(
            icn: expected_icn
          ).and_return(
            emis_response
          )

          expect(subject.is_veteran('veteran')).to eq(false)
        end
      end

      context 'when title38_status_code is not present' do
        it 'returns false' do
          subject = described_class.new(
            build(
              :caregivers_assistance_claim,
              form: {
                'veteran' => build_claim_data_for(:veteran),
                'primaryCaregiver' => build_claim_data_for(:primaryCaregiver)
              }.to_json
            )
          )

          expected_icn = :ICN_123
          emis_response = double(
            error?: false,
            items: []
          )

          expect(subject).to receive(:icn_for).with('veteran').and_return(expected_icn)
          expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status).with(
            icn: expected_icn
          ).and_return(
            emis_response
          )

          expect(subject.is_veteran('veteran')).to eq(false)
        end
      end

      context 'when the search fails' do
        it 'returns false' do
          subject = described_class.new(
            build(
              :caregivers_assistance_claim,
              form: {
                'veteran' => build_claim_data_for(:veteran),
                'primaryCaregiver' => build_claim_data_for(:primaryCaregiver)
              }.to_json
            )
          )

          expected_icn = :ICN_123
          emis_response = double(
            error?: true,
            error: Common::Client::Errors::HTTPError.new('BadRequest', 400, nil),
            items: []
          )

          expect(subject).to receive(:icn_for).with('veteran').and_return(expected_icn)
          expect_any_instance_of(EMIS::VeteranStatusService).to receive(:get_veteran_status).with(
            icn: expected_icn
          ).and_return(
            emis_response
          )

          expect(subject.is_veteran('veteran')).to eq(false)
        end
      end
    end

    it 'returns a cached responses when called more than once for a given subject' do
      subject = described_class.new(
        build(
          :caregivers_assistance_claim,
          form: {
            'veteran' => build_claim_data_for(:veteran),
            'primaryCaregiver' => build_claim_data_for(:primaryCaregiver)
          }.to_json
        )
      )

      emis_service = double
      expect(EMIS::VeteranStatusService).to receive(:new).with(no_args).and_return(emis_service)

      # Only two calls should be made to eMIS for the six calls of :is_veteran below
      2.times do |index|
        expected_form_subject = index.zero? ? 'veteran' : 'primaryCaregiver'
        expected_icn = "ICN_#{index}".to_sym

        expect(subject).to receive(:icn_for).with(expected_form_subject).and_return(expected_icn)

        emis_response_title38_value = index.zero? ? 'V1' : 'V4'
        emis_response = double(
          error?: false,
          items: [
            double(
              title38_status_code: emis_response_title38_value
            )
          ]
        )

        expect(emis_service).to receive(:get_veteran_status).with(
          icn: expected_icn
        ).and_return(
          emis_response
        )
      end

      3.times do
        expect(subject.is_veteran('veteran')).to eq(true)
        expect(subject.is_veteran('primaryCaregiver')).to eq(false)
      end
    end
  end

  describe '#build_metadata' do
    it 'returns the icn for each subject on the form and the veteran\'s status' do
      %w[veteran primaryCaregiver secondaryCaregiverOne].each_with_index do |form_subject, index|
        return_value = form_subject == 'secondaryCaregiverOne' ? 'NOT_FOUND' : "ICN_#{index}".to_sym
        expect(subject).to receive(:icn_for).with(form_subject).and_return(return_value)
      end

      expect(subject).not_to receive(:is_veteran)

      expect(subject.build_metadata).to eq(
        veteran: {
          icn: :ICN_0,
          is_veteran: false # this is hard coded to false, until vet status searches are fixed
        },
        primary_caregiver: {
          icn: :ICN_1
        },
        secondary_caregiver_one: {
          # Note that NOT_FOUND is converted to nil
          icn: nil
        }
      )
    end
  end

  describe '#assert_veteran_status' do
    it 'will raise error if veteran\'s icn can not be found' do
      expect(subject).to receive(:icn_for).with('veteran').and_return('NOT_FOUND')
      expect { subject.assert_veteran_status }.to raise_error(described_class::InvalidVeteranStatus)
    end

    it 'will not raise error if veteran\'s icn is found' do
      expect(subject).to receive(:icn_for).with('veteran').and_return(:ICN_123)
      expect(subject).not_to receive(:is_veteran)

      expect(subject.assert_veteran_status).to eq(nil)
    end
  end

  describe '#process_claim!' do
    it 'raises error when ICN not found for veteran' do
      expect(subject).to receive(:icn_for).with('veteran').and_return('NOT_FOUND')
      expect { subject.process_claim! }.to raise_error(described_class::InvalidVeteranStatus)
    end

    context 'with valid state' do
      let(:expected) do
        {
          results: {
            carma_case_id: 'aB935000000A9GoCAK',
            submitted_at: DateTime.new,
            metadata: { 'key' => 'value' }
          }
        }
      end

      before do
        expect(subject).to receive(:assert_veteran_status).and_return(nil)
        expect(subject).to receive(:build_metadata).and_return(:generated_metadata)
        expect(CARMA::Models::Submission).to receive(:from_claim).with(subject.claim, :generated_metadata) {
          carma_submission = double

          expect(carma_submission).to receive(:submit!) {
            expect(carma_submission).to receive(:carma_case_id).and_return(expected[:results][:carma_case_id])
            expect(carma_submission).to receive(:submitted_at).and_return(expected[:results][:submitted_at])
            expect(carma_submission).to receive(:request_body).and_return(
              { 'metadata' => expected[:results][:metadata] }
            )

            carma_submission
          }

          carma_submission
        }
        expect(subject).to receive(:submit_attachment_async)
      end

      it 'submits the claim to carma and returns a Form1010cg::Submission' do
        result = subject.process_claim!

        expect(result).to be_a(Form1010cg::Submission)
        expect(result.carma_case_id).to eq(expected[:results][:carma_case_id])
        expect(result.accepted_at).to eq(expected[:results][:submitted_at])
        expect(result.metadata).to eq(expected[:results][:metadata])
      end
    end
  end
end
