# frozen_string_literal: true

require 'rails_helper'
require 'ves_api/client'

RSpec.describe 'Transformation Pega', type: :request do
  let(:ves_client) { double('IvcChampva::VesApi::Client') }
  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:uuid) { SecureRandom.uuid }

  before do
    @original_aws_config = Aws.config.dup
    Aws.config.update(stub_responses: true)
    allow(IvcChampva::VesApi::Client).to receive(:new).and_return(ves_client)
    allow(ves_client).to receive(:submit_1010d).with(anything, anything, anything)
    allow(Flipper).to receive(:enabled?).with(:champva_update_metadata_keys).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:champva_update_datadog_tracking, anything).and_return(false)
  end

  after do
    Aws.config = @original_aws_config
  end

  describe '#submit' do
    champva_send_to_ves = [true, true, false, false]
    champva_retry_logic_refactor = [true, false, true, false]
    champva_send_to_ves.each_with_index do |flipper_value, flipper_index|
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:champva_send_to_ves, @current_user)
          .and_return(flipper_value)
        allow(Flipper).to receive(:enabled?)
          .with(:champva_retry_logic_refactor, @current_user)
          .and_return(champva_retry_logic_refactor[flipper_index])

        allow(SecureRandom).to receive(:uuid).and_return(uuid)
        allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
          .and_return(double('Record1', created_at: 1.day.ago,
                                        id: 'some_uuid', file: double(id: 'file0')))
        allow(s3_client).to receive(:put_object).and_return(
          double('response',
                 context: double('context', http_response: double('http_response', status_code: 200)))
        )
        allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      end

      describe '10_10d' do
        fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json')
        data = JSON.parse(fixture_path.read)

        before do
          allow(Flipper).to receive(:enabled?)
            .with(:champva_send_ves_to_pega, @current_user)
            .and_return(false)
        end

        it 'submits the form and verifies the transformed data going to Pega/S3' do
          post '/ivc_champva/v1/forms', params: data
          expect(response).to have_http_status(:ok)

          # Expect the PDF and it's corresponding metadata was uploaded
          expect(s3_client).to have_received(:put_object).once.with(
            hash_including(
              key: "#{uuid}_vha_10_10d.pdf",
              metadata: {
                veteranFirstName: data.dig('veteran', 'full_name', 'first'),
                veteranMiddleName: data.dig('veteran', 'full_name', 'middle'),
                veteranLastName: data.dig('veteran', 'full_name', 'last'),
                veteranEmail: data.dig('veteran', 'email'),
                sponsorFirstName: data.fetch('applicants').first.dig('applicant_name', 'first'),
                sponsorMiddleName: data.fetch('applicants').first.dig('applicant_name', 'middle'),
                sponsorLastName: data.fetch('applicants').first.dig('applicant_name', 'last'),
                fileNumber: data.dig('veteran', 'va_claim_number'),
                zipCode: data.dig('veteran', 'address', 'postal_code'),
                country: data.dig('veteran', 'address', 'country'),
                source: 'VA Platform Digital Forms',
                docType: data['form_number'],
                businessLine: 'CMP',
                ssn_or_tin: data.dig('veteran', 'ssn_or_tin'),
                uuid:,
                hasApplicantOver65: data['has_applicant_over65'].to_s,
                primaryContactEmail: data.dig('primary_contact_info', 'email').to_s,
                formExpiration: '12/31/2027',
                'applicant_0' => {
                  applicant_name: {
                    first: data.fetch('applicants').first.dig('applicant_name', 'first'),
                    middle: data.fetch('applicants').first.dig('applicant_name', 'middle'),
                    last: data.fetch('applicants').first.dig('applicant_name', 'last')
                  },
                  applicant_dob: data.fetch('applicants').first['applicant_dob']
                }.to_json,
                'applicant_1' => {
                  applicant_name: {
                    first: data.fetch('applicants').second.dig('applicant_name', 'first'),
                    middle: data.fetch('applicants').second.dig('applicant_name', 'middle'),
                    last: data.fetch('applicants').second.dig('applicant_name', 'last')
                  },
                  applicant_dob: data.fetch('applicants').second['applicant_dob']
                }.to_json,
                'applicant_2' => {
                  applicant_name: {
                    first: data.fetch('applicants').third.dig('applicant_name', 'first'),
                    middle: data.fetch('applicants').third.dig('applicant_name', 'middle'),
                    last: data.fetch('applicants').third.dig('applicant_name', 'last')
                  },
                  applicant_dob: data.fetch('applicants').third['applicant_dob']
                }.to_json,
                'applicant_3' => {
                  applicant_name: {
                    first: data.fetch('applicants').fourth.dig('applicant_name', 'first'),
                    middle: data.fetch('applicants').fourth.dig('applicant_name', 'middle'),
                    last: data.fetch('applicants').fourth.dig('applicant_name', 'last')
                  },
                  applicant_dob: data.fetch('applicants').fourth['applicant_dob']
                }.to_json,
                'applicant_4' => {
                  applicant_name: {
                    first: data.fetch('applicants').fifth.dig('applicant_name', 'first'),
                    middle: data.fetch('applicants').fifth.dig('applicant_name', 'middle'),
                    last: data.fetch('applicants').fifth.dig('applicant_name', 'last')
                  },
                  applicant_dob: data.fetch('applicants').fifth['applicant_dob']
                }.to_json,
                attachment_id: 'vha_10_10d'
              }.stringify_keys!
            )
          )

          # Expect the metadata.json file was uploaded
          expect(s3_client).to have_received(:put_object).once.with(
            hash_including(
              key: "#{uuid}_vha_10_10d_metadata.json",
              body: {
                veteranFirstName: data.dig('veteran', 'full_name', 'first'),
                veteranMiddleName: data.dig('veteran', 'full_name', 'middle'),
                veteranLastName: data.dig('veteran', 'full_name', 'last'),
                veteranEmail: data.dig('veteran', 'email'),
                sponsorFirstName: data.fetch('applicants').first.dig('applicant_name', 'first'),
                sponsorMiddleName: data.fetch('applicants').first.dig('applicant_name', 'middle'),
                sponsorLastName: data.fetch('applicants').first.dig('applicant_name', 'last'),
                fileNumber: data.dig('veteran', 'va_claim_number'),
                zipCode: data.dig('veteran', 'address', 'postal_code'),
                country: data.dig('veteran', 'address', 'country'),
                source: 'VA Platform Digital Forms',
                docType: data['form_number'],
                businessLine: 'CMP',
                ssn_or_tin: data.dig('veteran', 'ssn_or_tin'),
                uuid:,
                primaryContactInfo: {
                  name: data.dig('primary_contact_info', 'name'),
                  email: data.dig('primary_contact_info', 'email').to_s
                },
                hasApplicantOver65: data['has_applicant_over65'].to_s,
                primaryContactEmail: data.dig('primary_contact_info', 'email').to_s,
                formExpiration: '12/31/2027',
                'applicant_0' => {
                  applicant_name: {
                    first: data.fetch('applicants').first.dig('applicant_name', 'first'),
                    middle: data.fetch('applicants').first.dig('applicant_name', 'middle'),
                    last: data.fetch('applicants').first.dig('applicant_name', 'last')
                  },
                  applicant_dob: data.fetch('applicants').first['applicant_dob']
                }.to_json,
                'applicant_1' => {
                  applicant_name: {
                    first: data.fetch('applicants').second.dig('applicant_name', 'first'),
                    middle: data.fetch('applicants').second.dig('applicant_name', 'middle'),
                    last: data.fetch('applicants').second.dig('applicant_name', 'last')
                  },
                  applicant_dob: data.fetch('applicants').second['applicant_dob']
                }.to_json,
                'applicant_2' => {
                  applicant_name: {
                    first: data.fetch('applicants').third.dig('applicant_name', 'first'),
                    middle: data.fetch('applicants').third.dig('applicant_name', 'middle'),
                    last: data.fetch('applicants').third.dig('applicant_name', 'last')
                  },
                  applicant_dob: data.fetch('applicants').third['applicant_dob']
                }.to_json,
                'applicant_3' => {
                  applicant_name: {
                    first: data.fetch('applicants').fourth.dig('applicant_name', 'first'),
                    middle: data.fetch('applicants').fourth.dig('applicant_name', 'middle'),
                    last: data.fetch('applicants').fourth.dig('applicant_name', 'last')
                  },
                  applicant_dob: data.fetch('applicants').fourth['applicant_dob']
                }.to_json,
                'applicant_4' => {
                  applicant_name: {
                    first: data.fetch('applicants').fifth.dig('applicant_name', 'first'),
                    middle: data.fetch('applicants').fifth.dig('applicant_name', 'middle'),
                    last: data.fetch('applicants').fifth.dig('applicant_name', 'last')
                  },
                  applicant_dob: data.fetch('applicants').fifth['applicant_dob']
                }.to_json,
                attachment_ids: ['vha_10_10d', 'vha_10_10d', 'Birth certificate']
              }.to_json,
              metadata: {}
            )
          )
        end
      end

      describe '10_7959c' do
        fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_7959c.json')
        data = JSON.parse(fixture_path.read)

        it 'submits the form and verifies the transformed data going to Pega/S3' do
          post '/ivc_champva/v1/forms', params: data
          expect(response).to have_http_status(:ok)

          # Expect the PDF and it's corresponding metadata was uploaded
          expect(s3_client).to have_received(:put_object).once.with(
            hash_including(
              key: "#{uuid}_vha_10_7959c.pdf",
              metadata: {
                veteranFirstName: data.dig('applicant_name', 'first'),
                veteranMiddleName: data.dig('applicant_name', 'middle'),
                veteranLastName: data.dig('applicant_name', 'last'),
                fileNumber: data['applicant_ssn'],
                zipCode: data.dig('applicant_address', 'postal_code'),
                country: data.dig('applicant_address', 'country'),
                source: 'VA Platform Digital Forms',
                ssn_or_tin: data['applicant_ssn'],
                docType: data['form_number'],
                businessLine: 'CMP',
                uuid:,
                primaryContactEmail: data.dig('primary_contact_info', 'email').to_s,
                applicantEmail: data['applicant_email'],
                attachment_id: 'vha_10_7959c'
              }.stringify_keys!
            )
          )

          # Expect the metadata.json file was uploaded
          expect(s3_client).to have_received(:put_object).once.with(
            hash_including(
              key: "#{uuid}_vha_10_7959c_metadata.json",
              body: {
                veteranFirstName: data.dig('applicant_name', 'first'),
                veteranMiddleName: data.dig('applicant_name', 'middle'),
                veteranLastName: data.dig('applicant_name', 'last'),
                fileNumber: data['applicant_ssn'],
                zipCode: data.dig('applicant_address', 'postal_code'),
                country: data.dig('applicant_address', 'country'),
                source: 'VA Platform Digital Forms',
                ssn_or_tin: data['applicant_ssn'],
                docType: data['form_number'],
                businessLine: 'CMP',
                uuid:,
                primaryContactInfo: {
                  name: data.dig('primary_contact_info', 'name'),
                  email: data.dig('primary_contact_info', 'email').to_s
                },
                primaryContactEmail: data.dig('primary_contact_info', 'email').to_s,
                applicantEmail: data['applicant_email'],
                attachment_ids: ['vha_10_7959c']
              }.to_json,
              metadata: {}
            )
          )
        end
      end

      describe '10_7959a' do
        fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_7959a.json')
        data = JSON.parse(fixture_path.read)

        it 'submits the form and verifies the transformed data going to Pega/S3' do
          post '/ivc_champva/v1/forms', params: data
          expect(response).to have_http_status(:ok)

          # Expect the PDF and it's corresponding metadata was uploaded
          expect(s3_client).to have_received(:put_object).once.with(
            hash_including(
              key: "#{uuid}_vha_10_7959a.pdf",
              metadata: {
                veteranFirstName: data.dig('applicant_name', 'first'),
                veteranLastName: data.dig('applicant_name', 'last'),
                zipCode: data.dig('applicant_address', 'postal_code'),
                source: 'VA Platform Digital Forms',
                docType: data['form_number'],
                businessLine: 'CMP',
                ssn_or_tin: data['applicant_member_number'],
                member_number: data['applicant_member_number'],
                fileNumber: data['applicant_member_number'],
                country: data.dig('applicant_address', 'country'),
                uuid:,
                primaryContactEmail: data.dig('primary_contact_info', 'email').to_s,
                claim_type: data['claim_type'],
                attachment_id: 'vha_10_7959a'
              }.stringify_keys!
            )
          )

          # Expect the metadata.json file was uploaded
          expect(s3_client).to have_received(:put_object).once.with(
            hash_including(
              key: "#{uuid}_vha_10_7959a_metadata.json",
              body: {
                veteranFirstName: data.dig('applicant_name', 'first'),
                veteranLastName: data.dig('applicant_name', 'last'),
                zipCode: data.dig('applicant_address', 'postal_code'),
                source: 'VA Platform Digital Forms',
                docType: data['form_number'],
                businessLine: 'CMP',
                ssn_or_tin: data['applicant_member_number'],
                member_number: data['applicant_member_number'],
                fileNumber: data['applicant_member_number'],
                country: data.dig('applicant_address', 'country'),
                uuid:,
                primaryContactInfo: {
                  name: data.dig('primary_contact_info', 'name'),
                  email: data.dig('primary_contact_info', 'email').to_s,
                  phone: data.dig('primary_contact_info', 'phone')
                },
                primaryContactEmail: data.dig('primary_contact_info', 'email').to_s,
                claim_type: data['claim_type'],
                attachment_ids: %w[vha_10_7959a vha_10_7959a 0 1]
              }.to_json,
              metadata: {}
            )
          )
        end
      end

      describe '10_7959f_1' do
        fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_7959f_1.json')
        data = JSON.parse(fixture_path.read)

        it 'submits the form and verifies the transformed data going to Pega/S3' do
          post '/ivc_champva/v1/forms', params: data
          expect(response).to have_http_status(:ok)

          # Expect the PDF and it's corresponding metadata was uploaded
          expect(s3_client).to have_received(:put_object).once.with(
            hash_including(
              key: "#{uuid}_vha_10_7959f_1.pdf",
              metadata: {
                veteranFirstName: data.dig('veteran', 'full_name', 'first'),
                veteranMiddleName: data.dig('veteran', 'full_name', 'middle'),
                veteranLastName: data.dig('veteran', 'full_name', 'last'),
                fileNumber: data.dig('veteran', 'va_claim_number'),
                zipCode: data.dig('veteran', 'mailing_address', 'postal_code'),
                country: data.dig('veteran', 'mailing_address', 'country'),
                source: 'VA Platform Digital Forms',
                ssn_or_tin: data.dig('veteran', 'ssn'),
                docType: data['form_number'],
                businessLine: 'CMP',
                uuid:,
                primaryContactEmail: data.dig('primary_contact_info', 'email').to_s,
                attachment_id: 'vha_10_7959f_1'
              }.stringify_keys!
            )
          )

          # Expect the metadata.json file was uploaded
          expect(s3_client).to have_received(:put_object).once.with(
            hash_including(
              key: "#{uuid}_vha_10_7959f_1_metadata.json",
              body: {
                veteranFirstName: data.dig('veteran', 'full_name', 'first'),
                veteranMiddleName: data.dig('veteran', 'full_name', 'middle'),
                veteranLastName: data.dig('veteran', 'full_name', 'last'),
                fileNumber: data.dig('veteran', 'va_claim_number'),
                zipCode: data.dig('veteran', 'mailing_address', 'postal_code'),
                country: data.dig('veteran', 'mailing_address', 'country'),
                source: 'VA Platform Digital Forms',
                ssn_or_tin: data.dig('veteran', 'ssn'),
                docType: data['form_number'],
                businessLine: 'CMP',
                uuid:,
                primaryContactInfo: {
                  name: data.dig('primary_contact_info', 'name'),
                  email: data.dig('primary_contact_info', 'email').to_s
                },
                primaryContactEmail: data.dig('primary_contact_info', 'email').to_s,
                attachment_ids: %w[vha_10_7959f_1]
              }.to_json,
              metadata: {}
            )
          )
        end
      end

      describe '10_7959f_2' do
        fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_7959f_2.json')
        data = JSON.parse(fixture_path.read)

        it 'submits the form and verifies the transformed data going to Pega/S3' do
          post '/ivc_champva/v1/forms', params: data
          expect(response).to have_http_status(:ok)

          # Expect the PDF and it's corresponding metadata was uploaded
          expect(s3_client).to have_received(:put_object).once.with(
            hash_including(
              key: "#{uuid}_vha_10_7959f_2_combined.pdf",
              metadata: {
                veteranFirstName: data.dig('veteran', 'full_name', 'first'),
                veteranMiddleName: data.dig('veteran', 'full_name', 'middle'),
                veteranLastName: data.dig('veteran', 'full_name', 'last'),
                fileNumber: data.dig('veteran', 'va_claim_number'),
                zipCode: data.dig('veteran', 'mailing_address', 'postal_code'),
                country: data.dig('veteran', 'mailing_address', 'country'),
                source: 'VA Platform Digital Forms',
                ssn_or_tin: data.dig('veteran', 'ssn'),
                docType: data['form_number'],
                businessLine: 'CMP',
                uuid:,
                primaryContactEmail: data.dig('primary_contact_info', 'email'),
                formExpiration: '12/31/2027',
                attachment_id: 'vha_10_7959f_2'
              }.stringify_keys!
            )
          )

          # Expect the metadata.json file was uploaded
          expect(s3_client).to have_received(:put_object).once.with(
            hash_including(
              key: "#{uuid}_vha_10_7959f_2_metadata.json",
              body: {
                veteranFirstName: data.dig('veteran', 'full_name', 'first'),
                veteranMiddleName: data.dig('veteran', 'full_name', 'middle'),
                veteranLastName: data.dig('veteran', 'full_name', 'last'),
                fileNumber: data.dig('veteran', 'va_claim_number'),
                zipCode: data.dig('veteran', 'mailing_address', 'postal_code'),
                country: data.dig('veteran', 'mailing_address', 'country'),
                source: 'VA Platform Digital Forms',
                ssn_or_tin: data.dig('veteran', 'ssn'),
                docType: data['form_number'],
                businessLine: 'CMP',
                uuid:,
                primaryContactInfo: {
                  name: data.dig('primary_contact_info', 'name'),
                  email: data.dig('primary_contact_info', 'email')
                },
                primaryContactEmail: data.dig('primary_contact_info', 'email'),
                formExpiration: '12/31/2027',
                attachment_ids: %w[vha_10_7959f_2]
              }.to_json,
              metadata: {}
            )
          )
        end
      end
    end
  end
end
