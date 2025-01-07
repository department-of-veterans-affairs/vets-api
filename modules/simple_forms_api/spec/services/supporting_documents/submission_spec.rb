# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe SimpleFormsApi::SupportingDocuments::Submission do
  forms = SimpleFormsApi::SupportingDocuments::Submission::FORMS_WITH_SUPPORTING_DOCUMENTS

  before do
    allow(PersistentAttachments::MilitaryRecords).to receive(:new).and_call_original
    allow(BenefitsIntakeService::Service).to receive(:new).and_return(benefits_intake_service_double)
    allow(PersistentAttachmentSerializer).to receive(:new).and_call_original
  end

  describe '#submit' do
    shared_examples 'form submission' do |form_id|
      context "for form #{form_id}" do
        subject(:submit) { instance.submit }

        let(:params) { { form_id:, file: mock_attachment } }
        let(:current_user) { build(:user, :loa3) }
        let(:instance) { described_class.new(current_user, params) }
        let(:mock_attachment) { fixture_file_upload('doctors-note.gif') }
        let(:benefits_intake_service_double) { instance_double(BenefitsIntakeService::Service) }

        before do
          allow(benefits_intake_service_double).to receive(:valid_document?).and_return(params[:file].tempfile.path)
        end

        if described_class::BENEFITS_INTAKE_VALIDATION_FORMS.include?(form_id)
          it 'checks the validity of the document' do
            submit
            expect(benefits_intake_service_double).to have_received(:valid_document?)
          end

          context 'when file is valid' do
            it 'completes successfully' do
              expect { submit }.not_to raise_error
            end
          end
        else
          context 'when ActiveRecord validations fail' do
            let(:mock_attachment) { fixture_file_upload('invalid_idme_cert.crt', 'application/x-x509-ca-cert') }

            it 'raises an error' do
              expect { submit }.to raise_error(Common::Exceptions::ValidationErrors)
            end
          end
        end

        context 'when file is valid' do
          before { allow(benefits_intake_service_double).to receive(:valid_document?).and_return(true) }

          it 'creates the attachment' do
            submit
            expect(PersistentAttachments::MilitaryRecords).to have_received(:new).with(form_id:)
            expect(PersistentAttachment.last).to be_a(PersistentAttachments::MilitaryRecords)
          end

          it 'does not throw an error' do
            expect(submit).to be_a(PersistentAttachmentSerializer)
          end

          it 'serializes the persistent attachment' do
            submit
            expect(PersistentAttachmentSerializer).to have_received(:new)
          end
        end
      end
    end

    describe 'forms with supporting documents' do
      forms.each { |form| include_examples 'form submission', form }
    end
  end
end
