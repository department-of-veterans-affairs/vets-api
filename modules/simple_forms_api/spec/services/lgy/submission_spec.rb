# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe SimpleFormsApi::Lgy::Submission do
  forms = described_class::LGY_API_FORMS

  describe '#submit' do
    shared_context 'form submission' do |form_id|
      context "for form #{form_id}" do
        subject(:submit) { instance.submit }

        let(:fixture_path) { %w[modules simple_forms_api spec fixtures] }
        let(:form_name) { "vba_#{form_id.gsub('-', '_')}" }
        let(:form_class) { "SimpleFormsApi::#{form_name.titleize.delete(' ')}".constantize }
        let(:form_json_path) { Rails.root.join(*fixture_path, 'form_json', "#{form_name}.json") }
        let(:params) { JSON.parse(form_json_path.read) }
        let(:current_user) { build(:user, :loa3) }
        let(:instance) { described_class.new(current_user, params) }

        let(:mock_attachment) { fixture_file_upload('doctors-note.gif') }
        let(:response_status) { 'ACCEPTED' }
        let(:lgy_response_status) { 200 }
        let(:mock_lgy_response) do
          OpenStruct.new(
            status: lgy_response_status,
            body: { 'reference_number' => '123456', 'status' => response_status }
          )
        end
        let(:lgy_response_double) { instance_double(LGY::Service) }
        let(:notification_email_double) { instance_double(SimpleFormsApi::NotificationEmail) }
        let(:notification_response) { true }
        let(:email_flag_enabled?) { true }

        before do
          allow(form_class).to receive(:new).and_call_original
          allow(LGY::Service).to receive(:new).and_return(lgy_response_double)
          allow(lgy_response_double).to receive(:post_grant_application).and_return(mock_lgy_response)
          allow(SimpleFormsApi::NotificationEmail).to receive(:new).and_return(notification_email_double)
          allow(notification_email_double).to receive(:send).and_return(notification_response)
          allow(Flipper).to receive(:enabled?).with(:simple_forms_email_confirmations).and_return(email_flag_enabled?)
          allow(Rails.logger).to receive(:info)
          submit
        end

        it 'creates a new instance of the form class' do
          expect(form_class).to have_received(:new).with(params)
        end

        it "calls LGY service post_grant_application with the form's payload" do
          expect(lgy_response_double).to(
            have_received(:post_grant_application).with(payload: a_hash_including(formNumber: '26-4555'))
          )
        end

        it "logs the form's submission" do
          expect(Rails.logger).to have_received(:info).with(
            'Simple forms api - sent to lgy',
            hash_including(form_number: '26-4555', status: 'ACCEPTED', reference_number: '123456')
          )
        end

        context 'when simple_forms_email_confirmations is enabled' do
          let(:email_flag_enabled?) { true }

          context 'when the LGY service returns a status of 200' do
            let(:lgy_response_status) { 200 }

            context 'when LGY returns status of VALIDATED' do
              let(:response_status) { 'VALIDATED' }

              it 'sends a confirmation email' do
                expect(SimpleFormsApi::NotificationEmail).to(
                  have_received(:new).with(
                    a_hash_including(form_number: form_name),
                    a_hash_including(notification_type: :confirmation)
                  )
                )
                expect(notification_email_double).to have_received(:send)
              end
            end

            context 'when LGY returns status of ACCEPTED' do
              let(:response_status) { 'ACCEPTED' }

              it 'sends a confirmation email' do
                expect(SimpleFormsApi::NotificationEmail).to(
                  have_received(:new).with(
                    a_hash_including(form_number: form_name),
                    a_hash_including(notification_type: :confirmation)
                  )
                )
                expect(notification_email_double).to have_received(:send)
              end
            end

            context 'when LGY returns status of REJECTED' do
              let(:response_status) { 'REJECTED' }

              it 'sends a rejection email' do
                expect(SimpleFormsApi::NotificationEmail).to(
                  have_received(:new).with(
                    a_hash_including(form_number: form_name),
                    a_hash_including(notification_type: :rejected)
                  )
                )
                expect(notification_email_double).to have_received(:send)
              end
            end

            context 'when LGY returns status of DUPLICATE' do
              let(:response_status) { 'DUPLICATE' }

              it 'sends a duplicate email' do
                expect(SimpleFormsApi::NotificationEmail).to(
                  have_received(:new).with(
                    a_hash_including(form_number: form_name),
                    a_hash_including(notification_type: :duplicate)
                  )
                )
                expect(notification_email_double).to have_received(:send)
              end
            end

            context 'when LGY returns an unknown status' do
              let(:response_status) { 'RUH_ROH_RAGGY' }

              it 'does not send an email' do
                expect(notification_email_double).not_to have_received(:send)
              end
            end

            context 'when the email is not sent' do
              let(:notification_response) { false }

              it 'fails silently' do
                expect(submit).to eq(json: { reference_number: '123456', status: 'ACCEPTED' }, status: 200)
              end
            end
          end

          context 'when the LGY service throws an error', skip: 'TODO: refactor to handle this edge case' do
            before do
              allow(lgy_response_double).to(
                receive(:post_grant_application).and_raise(Common::Client::Errors::ClientError)
              )
            end

            it 'does not send an email' do
              expect(notification_email_double).not_to have_received(:send)
            end
          end
        end

        context 'when simple_forms_email_confirmations is not enabled' do
          let(:email_flag_enabled?) { false }

          it 'returns a hash with reference_number and status' do
            expect(submit).to eq(json: { reference_number: '123456', status: 'ACCEPTED' }, status: 200)
          end
        end

        context 'when the LGY service returns a status of 500' do
          let(:lgy_response_status) { 500 }
        end
      end
    end

    forms.each do |form_id|
      include_examples 'form submission', form_id
    end
  end
end
