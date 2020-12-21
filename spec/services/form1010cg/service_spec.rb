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
  end

  describe '::submit_attachment!' do
    let(:carma_case_id) { 'CAS_1234' }
    let(:veteran_name) { { 'first' => 'Jane', 'last' => 'Doe' } }
    let(:document_type) { '10-10CG' }
    let(:file_path) { 'tmp/pdfs/10-10CG_uuid-123.pdf' }

    it 'requires a carma_case_id, veteran_name, document_type, and file_path' do
      expect { described_class.submit_attachment! }.to raise_error(ArgumentError) do |e|
        expect(e.message).to eq('wrong number of arguments (given 0, expected 4)')
      end

      expect { described_class.submit_attachment!(carma_case_id) }.to raise_error(ArgumentError) do |e|
        expect(e.message).to eq('wrong number of arguments (given 1, expected 4)')
      end

      expect { described_class.submit_attachment!(carma_case_id, veteran_name) }.to raise_error(ArgumentError) do |e|
        expect(e.message).to eq('wrong number of arguments (given 2, expected 4)')
      end

      arguments = [carma_case_id, veteran_name, document_type]
      expect { described_class.submit_attachment!(*arguments) }.to raise_error(ArgumentError) do |e|
        expect(e.message).to eq('wrong number of arguments (given 3, expected 4)')
      end
    end

    context 'when veteran_name is invalid' do
      it 'raises error' do
        expect { described_class.submit_attachment!(carma_case_id, nil, document_type, file_path) }.to raise_error(
          'invalid veteran_name'
        )

        expect { described_class.submit_attachment!(carma_case_id, {}, document_type, file_path) }.to raise_error(
          'invalid veteran_name'
        )

        arguments = [carma_case_id, { 'fullName' => {} }, document_type, file_path]
        expect { described_class.submit_attachment!(*arguments) }.to raise_error(
          'invalid veteran_name'
        )
      end
    end

    context 'when document_type is invalid' do
      it 'raises error' do
        expect { described_class.submit_attachment!(carma_case_id, veteran_name, nil, file_path) }.to raise_error(
          'invalid document_type'
        )

        expect { described_class.submit_attachment!(carma_case_id, veteran_name, '', file_path) }.to raise_error(
          'invalid document_type'
        )

        arguments = [carma_case_id, veteran_name, 'other-doc-type', file_path]
        expect { described_class.submit_attachment!(*arguments) }.to raise_error(
          'invalid document_type'
        )
      end
    end

    describe 'on delivery' do
      let(:carma_attachments) { double }

      before do
        expect(CARMA::Models::Attachments).to receive(
          :new
        ).with(
          carma_case_id, veteran_name['first'], veteran_name['last']
        ).and_return(carma_attachments)

        expect(carma_attachments).to receive(:add).with('10-10CG', file_path).and_return(carma_attachments)
      end

      context 'when a client error occures' do
        before do
          expect(carma_attachments).to receive(:submit!).and_raise(Faraday::ClientError.new('bad request'))
        end

        it 'raises error' do
          submission_method = lambda do
            described_class.submit_attachment!(carma_case_id, veteran_name, '10-10CG', file_path)
          end
          expect { submission_method.call }.to raise_error(Faraday::ClientError)
        end
      end

      context 'when successful' do
        before do
          expect(carma_attachments).to receive(:submit!).and_return(:PROCESSED_ATTACHMENTS)
        end

        it 'returns attachments payload' do
          result = described_class.submit_attachment!(carma_case_id, veteran_name, document_type, file_path)
          expect(result).to eq(:PROCESSED_ATTACHMENTS)
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

    context 'when flipper :async_10_10_cg_attachments' do
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
      end

      context 'is enabled' do
        before do
          expect(Flipper).to receive(:enabled?).with(:async_10_10_cg_attachments).and_return(true)
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

      context 'is disabled' do
        before do
          expect(Flipper).to receive(:enabled?).with(:async_10_10_cg_attachments).and_return(false)
          expect(subject).to receive(:submit_attachment)
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

  describe '#submit_attachment' do
    context 'raises error' do
      it 'when submission is not present' do
        expect { subject.submit_attachment }.to raise_error('requires a submission')
      end

      it 'when submission is not yet processed' do
        subject.submission = double(carma_case_id: nil)
        expect { subject.submit_attachment }.to raise_error('requires a processed submission')
      end

      it 'when submission already has attachments' do
        subject.submission = double(carma_case_id: 'CAS_1234', attachments: [{ id: 'CAS_qwer' }])
        expect { subject.submit_attachment }.to raise_error('submission already has attachments')
      end
    end

    it 'submits the PDF version of submission to CARMA' do
      document_type     = '10-10CG'
      file_path         = 'tmp/my_file.pdf'
      carma_attachment  = double
      claim             = build(:caregivers_assistance_claim)

      submission = Form1010cg::Submission.new(
        carma_case_id: 'aB9350000000TjICAU',
        accepted_at: '2020-06-26 13:30:59'
      )

      subject = described_class.new(claim, submission)

      expect(subject.claim).to receive(:to_pdf).with(sign: true).and_return(file_path)

      expect(CARMA::Models::Attachments).to receive(:new).with(
        submission.carma_case_id,
        claim.veteran_data['fullName']['first'],
        claim.veteran_data['fullName']['last']
      ).and_return(
        carma_attachment
      )

      expect(carma_attachment).to receive(:add).with(document_type, file_path).and_return(carma_attachment)
      expect(carma_attachment).to receive(:submit!).and_return(:ATTACHMENT_RESPONSE)
      expect(carma_attachment).to receive(:to_hash).and_return(:attachments_as_hash)
      expect(submission).to receive(:attachments=).with(:attachments_as_hash)

      expect(File).to receive(:exist?).with(file_path).and_return(true)
      expect(File).to receive(:delete).with(file_path)

      expect(subject.submit_attachment).to eq(true)
    end

    it 'returns false when PDF generation fails' do
      claim = build(:caregivers_assistance_claim)

      submission = Form1010cg::Submission.new(
        carma_case_id: 'aB9350000000TjICAU',
        accepted_at: '2020-06-26 13:30:59'
      )

      subject = described_class.new(claim, submission)

      expect(subject.claim).to receive(:to_pdf).and_raise('pdf generation failure')
      expect(CARMA::Models::Attachments).not_to receive(:new)

      expect(subject.submit_attachment).to eq(false)
    end

    it 'returns false when building Attachments fails' do
      file_path = 'tmp/my_file.pdf'
      claim     = build(:caregivers_assistance_claim)

      submission = Form1010cg::Submission.new(
        carma_case_id: 'aB9350000000TjICAU',
        accepted_at: '2020-06-26 13:30:59'
      )

      subject = described_class.new(claim, submission)

      expect(subject.claim).to receive(:to_pdf).and_return(file_path)

      expect(CARMA::Models::Attachments).to receive(:new).and_raise('failure')

      expect(File).to receive(:exist?).with(file_path).and_return(true)
      expect(File).to receive(:delete).with(file_path)

      expect(subject.submit_attachment).to eq(false)
    end

    it 'returns false when adding an attachment fails' do
      document_type     = '10-10CG'
      file_path         = 'tmp/my_file.pdf'
      carma_attachment  = double
      claim             = build(:caregivers_assistance_claim)

      submission = Form1010cg::Submission.new(
        carma_case_id: 'aB9350000000TjICAU',
        accepted_at: '2020-06-26 13:30:59'
      )

      subject = described_class.new(claim, submission)

      expect(subject.claim).to receive(:to_pdf).and_return(file_path)

      expect(CARMA::Models::Attachments).to receive(:new).with(
        submission.carma_case_id,
        claim.veteran_data['fullName']['first'],
        claim.veteran_data['fullName']['last']
      ).and_return(
        carma_attachment
      )

      expect(carma_attachment).to receive(:add).with(document_type, file_path).and_raise('failure')

      expect(File).to receive(:exist?).with(file_path).and_return(true)
      expect(File).to receive(:delete).with(file_path)

      expect(subject.submit_attachment).to eq(false)
    end

    it 'returns false when submission fails' do
      document_type     = '10-10CG'
      file_path         = 'tmp/my_file.pdf'
      carma_attachment  = double
      claim             = build(:caregivers_assistance_claim)

      submission = Form1010cg::Submission.new(
        carma_case_id: 'aB9350000000TjICAU',
        accepted_at: '2020-06-26 13:30:59'
      )

      subject = described_class.new(claim, submission)

      expect(subject.claim).to receive(:to_pdf).and_return(file_path)

      expect(CARMA::Models::Attachments).to receive(:new).with(
        submission.carma_case_id,
        claim.veteran_data['fullName']['first'],
        claim.veteran_data['fullName']['last']
      ).and_return(
        carma_attachment
      )

      expect(carma_attachment).to receive(:add).with(document_type, file_path).and_return(carma_attachment)
      expect(carma_attachment).to receive(:submit!).and_raise('bad request')

      expect(File).to receive(:exist?).with(file_path).and_return(true)
      expect(File).to receive(:delete).with(file_path)

      expect(subject.submit_attachment).to eq(false)
    end

    it 'returns false when file is deleted from another source' do
      document_type     = '10-10CG'
      file_path         = 'tmp/my_file.pdf'
      carma_attachment  = double
      claim             = build(:caregivers_assistance_claim)

      submission = Form1010cg::Submission.new(
        carma_case_id: 'aB9350000000TjICAU',
        accepted_at: '2020-06-26 13:30:59'
      )

      subject = described_class.new(claim, submission)

      expect(subject.claim).to receive(:to_pdf).and_return(file_path)

      expect(CARMA::Models::Attachments).to receive(:new).with(
        submission.carma_case_id,
        claim.veteran_data['fullName']['first'],
        claim.veteran_data['fullName']['last']
      ).and_return(
        carma_attachment
      )

      expect(carma_attachment).to receive(:add).with(document_type, file_path).and_return(carma_attachment)
      expect(carma_attachment).to receive(:submit!).and_raise('bad request')

      expect(File).to receive(:exist?).with(file_path).and_return(false)
      expect(File).not_to receive(:delete).with(file_path)

      expect(subject.submit_attachment).to eq(false)
    end
  end
end
