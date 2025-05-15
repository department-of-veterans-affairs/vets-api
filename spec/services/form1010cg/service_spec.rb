# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/form1010cg_helpers/build_claim_data_for'
require 'common/file_helpers'

RSpec.describe Form1010cg::Service do
  include Form1010cgHelpers

  let(:subject) { described_class.new build(:caregivers_assistance_claim) }
  let(:default_email_on_mvi_search) { 'no-email@example.com' }

  let(:claim_with_mpi_veteran) do
    require 'saved_claim/caregivers_assistance_claim'

    claim = build(:caregivers_assistance_claim)
    claim.parsed_form['signAsRepresentative'] = true

    claim.parsed_form['veteran'].merge!(
      'fullName' => {
        'first' => 'WESLEY',
        'last' => 'FORD'
      },
      'gender' => 'M',
      'ssnOrTin' => '796043735',
      'dateOfBirth' => '1986-05-06'
    )

    pdf_fixture = 'spec/fixtures/carma/10-10CG_f6056cff-d4cb-4058-8fb0-42296e12698f.pdf'
    allow_any_instance_of(SavedClaim::CaregiversAssistanceClaim).to receive(:to_pdf).with(sign: true).and_return(
      pdf_fixture
    )
    allow(File).to receive(:delete).and_call_original
    allow(File).to receive(:delete).with(pdf_fixture)

    claim
  end

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
      expected_errors = %w[primaryCaregiver secondaryCaregiverOne veteran].map do |field|
        have_attributes(
          title: include(" object at root is missing required properties: #{field}"),
          detail: include(" - object at root is missing required properties: #{field}"),
          status: '422',
          code: '100'
        )
      end

      expect { described_class.new(SavedClaim::CaregiversAssistanceClaim.new(form: '{}')) }.to raise_error do |e|
        expect(e).to be_a(Common::Exceptions::ValidationErrors)
        expect(e.errors.size).to eq(3)

        expect(e.errors).to match_array(expected_errors)
      end
    end

    it 'sets claim' do
      claim = build(:caregivers_assistance_claim)
      service = described_class.new claim

      expect(service.claim).to eq(claim)
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

      expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes).and_return(
        create(:find_profile_response, profile: double(icn: :ICN_123))
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

      expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes).and_return(
        create(:find_profile_not_found_response, error: double(message: 'some-message'))
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

      expect_any_instance_of(MPI::Service).not_to receive(:find_profile_by_attributes)

      result = subject.icn_for('primaryCaregiver')

      expect(result).to eq('NOT_FOUND')
    end

    it 'returns "NOT_FOUND" when nothing is found and no error is returned' do
      subject = described_class.new(
        build(
          :caregivers_assistance_claim,
          form: {
            'veteran' => build_claim_data_for(:veteran),
            'primaryCaregiver' => build_claim_data_for(:primaryCaregiver)
          }.to_json
        )
      )

      expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes).and_return(
        OpenStruct.new(ok?: false, not_found?: false, error: nil)
      )

      result = subject.icn_for('veteran')

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

      expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes).with(
        first_name: veteran_data['fullName']['first'],
        last_name: veteran_data['fullName']['last'],
        birth_date: veteran_data['dateOfBirth'],
        ssn: veteran_data['ssnOrTin']
      ).and_return(
        create(:find_profile_response, profile: double(icn: :CACHED_VALUE))
      )

      expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes).with(
        first_name: pc_data['fullName']['first'],
        last_name: pc_data['fullName']['last'],
        birth_date: pc_data['dateOfBirth'],
        ssn: pc_data['ssnOrTin']
      ).and_return(
        create(:find_profile_not_found_response, error: double(message: 'some-message'))
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
      it 'provids that email in the mvi search' do
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

        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes).with(
          first_name: veteran_data['fullName']['first'],
          last_name: veteran_data['fullName']['last'],
          birth_date: veteran_data['dateOfBirth'],
          ssn: veteran_data['ssnOrTin']
        ).and_return(create(:find_profile_response, profile: double(icn: :ICN_123)))

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

      it 'logs the result of a successful search' do
        %w[veteran primaryCaregiver secondaryCaregiverOne secondaryCaregiverTwo].each do |form_subject|
          expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes).and_return(
            create(:find_profile_response, profile: double(icn: :ICN_123))
          )

          expect(described_class::AUDITOR).to receive(:log_mpi_search_result).with(
            claim_guid: subject.claim.guid,
            form_subject:,
            result: :found
          )

          subject.icn_for(form_subject)
        end
      end

      it 'logs the result of a unsuccessful search' do
        %w[veteran primaryCaregiver secondaryCaregiverOne secondaryCaregiverTwo].each do |form_subject|
          expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes).and_return(
            create(:find_profile_not_found_response, error: double(message: 'some-message'))
          )

          expect(described_class::AUDITOR).to receive(:log_mpi_search_result).with(
            claim_guid: subject.claim.guid,
            form_subject:,
            result: :not_found
          )

          subject.icn_for(form_subject)
        end
      end

      it 'logs when a search is skipped' do
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
            form_subject:,
            result: :skipped
          )

          subject.icn_for(form_subject)
        end
      end

      it 'raises an error when the response has an error' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes).and_return(
          OpenStruct.new(
            ok?: false,
            error: StandardError
          )
        )

        expect do
          subject.icn_for('veteran')
        end.to raise_error(StandardError)
      end

      it 'does not log the search result when reading from cache' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes).and_return(
          create(:find_profile_response, profile: double(icn: :ICN_123))
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

  describe '#build_metadata' do
    it 'returns the icn for each subject on the form and the veteran\'s status' do
      %w[veteran primaryCaregiver secondaryCaregiverOne].each_with_index do |form_subject, index|
        return_value = form_subject == 'secondaryCaregiverOne' ? 'NOT_FOUND' : :"ICN_#{index}"
        expect(subject).to receive(:icn_for).with(form_subject).and_return(return_value)
      end

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
    it "raises error if veteran's icn can not be found" do
      expect(subject).to receive(:icn_for).with('veteran').and_return('NOT_FOUND')
      expect(subject).to receive(:log_exception_to_sentry).with(instance_of(described_class::InvalidVeteranStatus))
      expect { subject.assert_veteran_status }.to raise_error(described_class::InvalidVeteranStatus)
    end

    it "does not raise error if veteran's icn is found" do
      expect(subject).to receive(:icn_for).with('veteran').and_return(:ICN_123)

      expect(subject.assert_veteran_status).to be_nil
    end
  end

  describe '#generate_records', run_at: '2022-08-02 17:12:53 -0700' do
    subject do
      require 'saved_claim/caregivers_assistance_claim'
      described_class.new(create(:caregivers_assistance_claim))
    end

    context 'with claim pdf' do
      let(:claim_pdf_path) { Common::FileHelpers.generate_clamav_temp_file('foo', 'claim.pdf') }

      after do
        File.delete(claim_pdf_path)
      end

      it 'generates the right records' do
        expect(subject.send(:generate_records, claim_pdf_path, nil)).to eq(
          [{ 'attributes' => { 'type' => 'ContentVersion', 'referenceId' => '1010CG' },
             'Title' => '10-10CG_Jane Doe_Doe_08-03-2022',
             'PathOnClient' => 'claim.pdf',
             'CARMA_Document_Type__c' => '10-10CG',
             'CARMA_Document_Date__c' => '2022-08-03',
             'VersionData' => 'Zm9v' }]
        )
      end

      context 'with poa pdf' do
        let(:poa_pdf_path) { Common::FileHelpers.generate_clamav_temp_file('foo', 'poa.pdf') }

        after do
          File.delete(poa_pdf_path)
        end

        it 'generates the right records' do
          expect(subject.send(:generate_records, claim_pdf_path, poa_pdf_path)).to eq(
            [{ 'attributes' => { 'type' => 'ContentVersion', 'referenceId' => '1010CG' },
               'Title' => '10-10CG_Jane Doe_Doe_08-03-2022',
               'PathOnClient' => 'claim.pdf',
               'CARMA_Document_Type__c' => '10-10CG',
               'CARMA_Document_Date__c' => '2022-08-03',
               'VersionData' => 'Zm9v' },
             { 'attributes' => { 'type' => 'ContentVersion', 'referenceId' => 'Legal Representative' },
               'Title' => 'Legal Representative_Jane Doe_Doe_08-03-2022',
               'PathOnClient' => 'poa.pdf',
               'CARMA_Document_Type__c' => 'Legal Representative',
               'CARMA_Document_Date__c' => '2022-08-03',
               'VersionData' => 'Zm9v' }]
          )
        end
      end
    end
  end

  describe '#process_claim_v2!' do
    subject do
      service.process_claim_v2!
    end

    let(:service) { described_class.new(claim_with_mpi_veteran) }
    let(:mule_soft_client) { instance_double(CARMA::Client::MuleSoftClient) }
    let(:mule_soft_payload) { { fake_payload: 'value' } }

    before do
      profile = double(:profile, icn: 'something')
      profile_response = double(:mpi_response, ok?: true, profile:)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes).and_return(profile_response)

      from_claim_result = double(:from_claim_result)
      allow(CARMA::Models::Submission).to receive(:from_claim).and_return(from_claim_result)
      allow(from_claim_result).to receive(:to_request_payload).and_return(mule_soft_payload)

      allow(CARMA::Client::MuleSoftClient).to receive(:new).and_return(mule_soft_client)
    end

    context 'success' do
      before do
        allow(mule_soft_client).to receive(:create_submission_v2)
      end

      it 'submits to mulesoft' do
        start_time = Time.current
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { start_time }
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC, :float_millisecond)
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_THREAD_CPUTIME_ID, :float_millisecond)
        expected_arguments = { context: :process, event: :success, start_time: }
        expect(described_class::AUDITOR).to receive(:log_caregiver_request_duration).with(
          **expected_arguments
        )

        subject
        expect(mule_soft_client).to have_received(:create_submission_v2).with(mule_soft_payload)
      end

      context 'with a poa attachment' do
        it 'submits to mulesoft' do
          claim_with_mpi_veteran.parsed_form['poaAttachmentId'] = create(:form1010cg_attachment, :with_attachment).guid

          expect_any_instance_of(Form1010cg::Attachment).to receive(:to_local_file).and_return(
            'spec/fixtures/files/doctors-note.jpg'
          )

          allow(File).to receive(:delete).with('spec/fixtures/files/doctors-note.jpg')

          subject

          expect(mule_soft_client).to have_received(:create_submission_v2).with(mule_soft_payload)
          expect(File).to have_received(:delete).with('spec/fixtures/files/doctors-note.jpg')
        end
      end
    end

    context 'handles errors' do
      let(:exception) { Common::Client::Errors::ClientError.new(message: 'something happened') }

      before do
        allow(Rails.logger).to receive(:info)
        allow(mule_soft_client).to receive(:create_submission_v2).and_raise(exception)
      end

      it 'logs claim_guid for any exceptions and raises error' do
        expect(service).to receive(:log_exception_to_sentry)
          .with(exception, {
                  form: '10-10CG',
                  claim_guid: claim_with_mpi_veteran.guid
                })

        start_time = Time.current
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { start_time }
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC, :float_millisecond)
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_THREAD_CPUTIME_ID, :float_millisecond)
        expected_arguments = { context: :process, event: :failure, start_time: }
        expect(described_class::AUDITOR).to receive(:log_caregiver_request_duration).with(
          **expected_arguments
        )

        expect { subject }.to raise_error(exception)
      end
    end
  end
end
