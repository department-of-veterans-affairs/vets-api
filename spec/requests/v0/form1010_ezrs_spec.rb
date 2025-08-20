# frozen_string_literal: true

require 'rails_helper'
require 'form1010_ezr/veteran_enrollment_system/associations/service'

RSpec.describe 'V0::Form1010Ezrs', type: :request do
  let(:form) do
    File.read('spec/fixtures/form1010_ezr/valid_form.json')
  end

  let(:headers) do
    {
      'CONTENT_TYPE' => 'application/json',
      'HTTP_X_KEY_INFLECTION' => 'camel'
    }
  end

  describe 'POST create' do
    subject do
      post(
        v0_form1010_ezrs_path,
        params: params.to_json,
        headers:
      )
    end

    context 'while unauthenticated' do
      let(:params) do
        { form: }
      end

      it 'returns an error in the response body' do
        subject

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors'][0]['detail']).to eq('Not authorized')
      end
    end

    context 'while authenticated', :skip_mvi do
      let(:current_user) { build(:evss_user, :loa3, icn: '1013032368V065534') }

      before do
        sign_in_as(current_user)
      end

      context 'when no error occurs' do
        before do
          allow_any_instance_of(
            Form1010Ezr::VeteranEnrollmentSystem::Associations::Service
          ).to receive(:reconcile_and_update_associations).and_return(
            {
              status: 'success',
              message: 'All associations were updated successfully',
              timestamp: Time.current.iso8601
            }
          )
        end

        let(:params) do
          { form: }
        end
        let(:body) do
          {
            'formSubmissionId' => nil,
            'timestamp' => nil,
            'success' => true
          }
        end

        it 'increments statsd' do
          expect { subject }.to trigger_statsd_increment('api.1010ezr.submission_attempt')
        end

        it 'renders a successful response and deletes the saved form' do
          VCR.use_cassette(
            'form1010_ezr/authorized_submit_async',
            { match_requests_on: %i[method uri body], erb: true }
          ) do
            expect_any_instance_of(ApplicationController).to receive(:clear_saved_form).with('10-10EZR').once
            subject
            expect(JSON.parse(response.body)).to eq(body)
          end
        end
      end

      context "when the 'ezr_emergency_contacts_enabled' flipper is enabled" do
        before do
          allow(Flipper).to receive(:enabled?).with(:ezr_emergency_contacts_enabled, instance_of(User)).and_return(true)
        end

        context 'when an error occurs in the associations service' do
          let(:form) do
            File.read('spec/fixtures/form1010_ezr/valid_form_with_next_of_kin_and_emergency_contact.json')
          end

          let(:params) do
            { form: }
          end

          before do
            allow_any_instance_of(
              Form1010Ezr::VeteranEnrollmentSystem::Associations::Service
            ).to receive(:get_associations).and_raise(
              Common::Exceptions::ResourceNotFound.new(detail: 'No record found for a person with the specified ICN')
            )
          end

          it 'returns an error response', run_at: 'Tue, 21 Nov 2023 20:42:44 GMT' do
            VCR.use_cassette(
              'form1010_ezr/authorized_submit',
              { match_requests_on: %i[method uri body], erb: true }
            ) do
              subject

              expect(response).to have_http_status(:not_found)
              expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
                'No record found for a person with the specified ICN'
              )
            end
          end
        end
      end
    end
  end

  describe 'POST download_pdf' do
    subject do
      post(
        v0_form1010_ezrs_download_pdf_path,
        params: params.to_json,
        headers:
      )
    end

    let(:params) { { form: } }

    context 'while unauthenticated' do
      it 'returns an error in the response body' do
        subject

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors'][0]['detail']).to eq('Not authorized')
      end
    end

    context 'while authenticated', :skip_mvi do
      let(:current_user) { build(:evss_user, :loa3, icn: '1013032368V065534') }

      let(:response_pdf) { Rails.root.join 'tmp', 'pdfs', '10-10EZ_from_response.pdf' }
      let(:expected_pdf) { Rails.root.join 'spec', 'fixtures', 'pdf_fill', '10-10EZR', 'unsigned', 'simple.pdf' }
      let(:body) { { form: }.to_json }

      before do
        allow(SecureRandom).to receive(:uuid).and_return('file-name-uuid')
        sign_in_as(current_user)
      end

      after do
        FileUtils.rm_f(response_pdf)
      end

      it 'returns a completed PDF' do
        subject

        expect(response).to have_http_status(:ok)

        veteran_full_name = JSON.parse(form)['veteranFullName']
        expected_filename = "10-10EZR_#{veteran_full_name['first']}_#{veteran_full_name['last']}.pdf"

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Disposition']).to include("filename=\"#{expected_filename}\"")
        expect(response.content_type).to eq('application/pdf')
        expect(response.body).to start_with('%PDF')
      end

      it 'ensures the tmp file is deleted when send_data fails' do
        allow_any_instance_of(ApplicationController).to receive(:send_data).and_raise(StandardError, 'send_data failed')

        subject

        expect(response).to have_http_status(:internal_server_error)
        expect(
          File.exist?('tmp/pdfs/10-10EZR_file-name-uuid.pdf')
        ).to be(false)
      end

      it 'ensures the tmp file is deleted when fill_form fails after retries' do
        expect(PdfFill::Filler).to receive(:fill_ancillary_form).exactly(3).times.and_raise(StandardError,
                                                                                            'error filling form')

        subject

        expect(response).to have_http_status(:internal_server_error)

        expect(
          File.exist?('tmp/pdfs/10-10EZR_file-name-uuid.pdf')
        ).to be(false)
      end
    end
  end
end
