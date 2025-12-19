# frozen_string_literal: true

require 'rails_helper'
require 'dependents/error_classes'

RSpec.describe SavedClaim::DependencyClaim do
  subject { create(:dependency_claim) }

  let(:subject_v2) { create(:dependency_claim_v2) }

  let(:all_flows_payload) { build(:form_686c_674_kitchen_sink) }
  let(:all_flows_payload_v2) { build(:form686c_674_v2) }
  let(:adopted_child) { build(:adopted_child_lives_with_veteran) }
  let(:adopted_child_v2) { build(:adopted_child_lives_with_veteran_v2) }
  let(:form_674_only) { build(:form_674_only) }
  let(:form_674_only_v2) { build(:form_674_only_v2) }
  let(:doc_type) { '148' }
  let(:va_file_number) { subject.parsed_form['veteran_information']['va_file_number'] }
  let(:va_file_number_v2) { subject_v2.parsed_form['veteran_information']['va_file_number'] }
  let(:va_file_number_with_payload) do
    {
      'veteran_information' => {
        'birth_date' => '1809-02-12',
        'full_name' => {
          'first' => 'WESLEY', 'last' => 'FORD', 'middle' => nil
        },
        'ssn' => va_file_number,
        'va_file_number' => va_file_number
      }
    }
  end
  let(:va_file_number_with_payload_v2) do
    {
      'veteran_information' => {
        'birth_date' => '1809-02-12',
        'full_name' => {
          'first' => 'WESLEY', 'last' => 'FORD', 'middle' => nil
        },
        'ssn' => va_file_number_v2,
        'va_file_number' => va_file_number_v2
      }
    }
  end

  let(:file_path) { "tmp/pdfs/686C-674_#{subject.id}_final.pdf" }
  let(:file_path_v2) { "tmp/pdfs/686C-674-V2_#{subject_v2.id}_final.pdf" }

  before do
    # Mock expensive PDF operations to avoid file I/O
    allow(PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
    allow(File).to receive(:rename)
    allow(Common::FileHelpers).to receive(:delete_file_if_exists)
    datestamp_instance = instance_double(PDFUtilities::DatestampPdf, run: 'tmp/pdfs/mock_processed.pdf')
    allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(datestamp_instance)
  end

  context 'when there is an error with PdfFill::Filler' do
    let(:error) { StandardError.new('PDF Fill Error') }

    before { allow(PdfFill::Filler).to receive(:fill_form).and_raise(error) }

    it 'raises a StandardError and tracks the error when PdfFill::Filler fails' do
      expect(subject.monitor).to receive(:track_to_pdf_failure).with(error, '686C-674')
      expect { subject.to_pdf(form_id: '686C-674') }.to raise_error(error)
    end
  end

  describe 'both forms' do
    context 'processing a v1 payload' do
      subject { described_class.new(form: all_flows_payload.to_json) }

      describe '#formatted_686_data' do
        it 'returns all data for 686 submissions' do
          formatted_data = subject.formatted_686_data(va_file_number_with_payload)
          expect(formatted_data).to include(:veteran_information)
        end
      end

      describe '#formatted_674_data' do
        it 'returns all data for 674 submissions' do
          formatted_data = subject.formatted_674_data(va_file_number_with_payload)
          expect(formatted_data).to include(:dependents_application)
          expect(formatted_data[:dependents_application]).to include(:student_name_and_ssn)
        end
      end

      describe '#submittable_686?' do
        it 'checks if there are 686 flows to process' do
          expect(subject.submittable_686?).to be(true)
        end
      end

      describe '#submittable_674?' do
        it 'checks if there are 674 to process' do
          expect(subject.submittable_674?).to be(true)
        end
      end
    end

    context 'processing a v2 payload' do
      subject { described_class.new(form: all_flows_payload_v2.to_json, use_v2: true) }

      describe '#formatted_686_data' do
        it 'returns all data for 686 submissions' do
          formatted_data = subject.formatted_686_data(va_file_number_with_payload_v2)
          expect(formatted_data).to include(:veteran_information)
        end
      end

      describe '#formatted_674_data' do
        it 'returns all data for 674 submissions' do
          formatted_data = subject.formatted_674_data(va_file_number_with_payload_v2)
          expect(formatted_data).to include(:dependents_application)
          expect(formatted_data[:dependents_application]).to include(:student_information)
        end
      end

      describe '#submittable_686?' do
        it 'checks if there are 686 flows to process' do
          expect(subject.submittable_686?).to be(true)
        end
      end

      describe '#submittable_674?' do
        it 'checks if there are 674 to process' do
          expect(subject.submittable_674?).to be(true)
        end
      end
    end
  end

  describe '674 form only' do
    context 'processing a v1 payload' do
      subject { described_class.new(form: form_674_only.to_json) }

      describe '#submittable_686?' do
        it 'returns false if there is no 686 to process' do
          expect(subject.submittable_686?).to be(false)
        end
      end
    end

    context 'processing a v2 payload' do
      subject { described_class.new(form: form_674_only_v2.to_json, use_v2: true) }

      describe '#submittable_686?' do
        it 'returns false if there is no 686 to process' do
          expect(subject.submittable_686?).to be(false)
        end
      end
    end
  end

  describe 'with adopted child' do
    context 'processing a v1 payload' do
      subject { described_class.new(form: adopted_child.to_json) }

      describe '#submittable_674?' do
        it 'returns false if there is no 674 to process' do
          expect(subject.submittable_674?).to be(false)
        end
      end

      describe '#regional_office' do
        it 'expects to be empty always' do
          expect(subject.regional_office).to eq([])
        end
      end
    end

    context 'processing a v2 payload' do
      subject { described_class.new(form: adopted_child_v2.to_json, use_v2: true) }

      describe '#submittable_674?' do
        it 'returns false if there is no 674 to process' do
          expect(subject.submittable_674?).to be(false)
        end
      end

      describe '#regional_office' do
        it 'expects to be empty always' do
          expect(subject.regional_office).to eq([])
        end
      end
    end
  end

  context 'v2 form on and vets json schema enabled' do
    subject { described_class.new(form: all_flows_payload_v2.to_json, use_v2: true) }

    before do
      allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:dependents_bypass_schema_validation).and_return(false)
    end

    it 'has a form id of 686C-674-V2' do
      expect(subject.form_id).to eq('686C-674-V2')
    end

    context 'after create' do
      it 'tracks pdf overflow' do
        allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_return(true)
        allow(StatsD).to receive(:increment)
        subject.save!

        tags = ['form_id:686C-674-V2']
        expect(StatsD).to have_received(:increment).with('saved_claim.pdf.overflow', tags:)
        expect(StatsD).to have_received(:increment).with('saved_claim.create', tags: tags + ['doctype:148'])
      end

      it 'calls PdfFill::Filler.fill_form during PDF overflow tracking' do
        allow(StatsD).to receive(:increment)
        expect(PdfFill::Filler).to receive(:fill_form).at_least(:once)
        subject.save!
      end
    end

    context 'with bad schema data' do
      before do
        subject.parsed_form['statement_of_truth_signature'] = nil
        subject.form = subject.parsed_form.to_json
      end

      it 'rejects the bad payload' do
        subject.validate
        expect(subject).not_to be_valid
      end
    end
  end

  context 'v2 form and vets json schema disabled' do
    subject { described_class.new(form: all_flows_payload_v2.to_json, use_v2: true) }

    before do
      allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:dependents_bypass_schema_validation).and_return(true)
    end

    it 'has a form id of 686C-674-V2' do
      expect(subject.form_id).to eq('686C-674-V2')
    end

    context 'after create' do
      it 'tracks pdf overflow' do
        allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_return(true)
        allow(StatsD).to receive(:increment)
        subject.save!

        tags = ['form_id:686C-674-V2']
        expect(StatsD).to have_received(:increment).with('saved_claim.pdf.overflow', tags:)
        expect(StatsD).to have_received(:increment).with('saved_claim.create', tags: tags + ['doctype:148'])
      end

      it 'ensures PDF tracking works with schema validation disabled' do
        allow(StatsD).to receive(:increment)
        expect(PdfFill::Filler).to receive(:fill_form).at_least(:once)
        subject.save!
      end
    end

    context 'with bad schema data' do
      before do
        subject.parsed_form['statement_of_truth_signature'] = nil
        subject.form = subject.parsed_form.to_json
      end

      it 'accepts the bad payload' do
        subject.validate
        expect(subject).to be_valid
      end
    end
  end

  describe '#send_failure_email' do
    let(:email) { 'test@example.com' }
    let(:today_string) { 'August 15, 2025' }
    let(:confirmation_number) { subject.guid }
    let(:first_name) { 'JOHN' }

    let(:expected_personalisation) do
      {
        'first_name' => first_name,
        'date_submitted' => today_string,
        'confirmation_number' => confirmation_number
      }
    end

    before do
      allow(Dependents::Form686c674FailureEmailJob).to receive(:perform_async)
      subject.parsed_form['dependents_application']['veteran_information']['full_name']['first'] = first_name.downcase
    end

    context 'when both 686c and 674 forms are submittable' do
      before do
        allow_any_instance_of(SavedClaim::DependencyClaim)
          .to receive_messages(submittable_686?: true, submittable_674?: true)
      end

      it 'sends a combo email with the correct parameters', run_at: 'Thu, 15 Aug 2025 15:30:00 GMT' do
        expect(Dependents::Form686c674FailureEmailJob)
          .to receive(:perform_async)
          .with(
            subject.id,
            email,
            Settings.vanotify.services.va_gov.template_id.form21_686c_674_action_needed_email,
            expected_personalisation
          )

        subject.send_failure_email(email)
      end
    end

    context 'when only 686c form is submittable' do
      before do
        allow_any_instance_of(SavedClaim::DependencyClaim)
          .to receive_messages(submittable_686?: true, submittable_674?: false)
      end

      it 'sends a 686c email with the correct parameters', run_at: 'Thu, 15 Aug 2025 15:30:00 GMT' do
        expect(Dependents::Form686c674FailureEmailJob)
          .to receive(:perform_async)
          .with(
            subject.id,
            email,
            Settings.vanotify.services.va_gov.template_id.form21_686c_action_needed_email,
            expected_personalisation
          )

        subject.send_failure_email(email)
      end
    end

    context 'when only 674 form is submittable' do
      before do
        allow_any_instance_of(SavedClaim::DependencyClaim)
          .to receive_messages(submittable_686?: false, submittable_674?: true)
      end

      it 'sends a 674 email with the correct parameters', run_at: 'Thu, 15 Aug 2025 15:30:00 GMT' do
        expect(Dependents::Form686c674FailureEmailJob)
          .to receive(:perform_async)
          .with(
            subject.id,
            email,
            Settings.vanotify.services.va_gov.template_id.form21_674_action_needed_email,
            expected_personalisation
          )

        subject.send_failure_email(email)
      end
    end

    context 'when neither form is submittable' do
      before do
        allow_any_instance_of(SavedClaim::DependencyClaim)
          .to receive_messages(submittable_686?: false, submittable_674?: false)

        allow(Rails.logger).to receive(:error)
      end

      it 'logs an error and does not send email', run_at: 'Thu, 15 Aug 2025 15:30:00 GMT' do
        expect(Rails.logger).to receive(:error).with('Email template cannot be assigned for SavedClaim',
                                                     saved_claim_id: subject.id)
        expect(Dependents::Form686c674FailureEmailJob).not_to receive(:perform_async)

        subject.send_failure_email(email)
      end
    end

    context 'when email is blank' do
      it 'does not send an email', run_at: 'Thu, 15 Aug 2025 15:30:00 GMT' do
        expect(Dependents::Form686c674FailureEmailJob).not_to receive(:perform_async)

        subject.send_failure_email('')
      end
    end

    context 'when overflow tracking fails' do
      let(:standard_error) { StandardError.new('test error') }
      let(:claim_data) { build(:dependency_claim).attributes }

      before do
        allow(Flipper).to receive(:enabled?)
          .with(:saved_claim_pdf_overflow_tracking).and_return(true)

        allow(PdfFill::Filler).to receive(:fill_form).and_return('fake_path.pdf')
        allow(Common::FileHelpers).to receive(:delete_file_if_exists).and_raise(standard_error)
      end

      it 'has the monitor track the failure' do
        claim = SavedClaim::DependencyClaim.new(claim_data)
        expect(claim.monitor).to receive(:track_pdf_overflow_tracking_failure).with(standard_error)
        claim.save!
      end
    end

    context 'when address is not present' do
      let(:claim_data) { build(:dependency_claim).attributes }

      it 'flags an error if the address is not present' do
        claim = SavedClaim::DependencyClaim.new(claim_data)
        claim.parsed_form['dependents_application']['veteran_contact_information'].delete('veteran_address')

        expect(claim).not_to be_valid
        expect(claim.errors.attribute_names).to include(:parsed_form)
        expect(claim.errors[:parsed_form]).to include("Veteran address can't be blank")
      end
    end
  end

  context 'when 686 data is invalid' do
    let(:claim_data) { build(:dependency_claim).attributes }
    let(:claim) { SavedClaim::DependencyClaim.new(claim_data) }

    it 'flags an error when the veteran ssn is not present' do
      claim.parsed_form['veteran_information'].delete('ssn')
      claim.valid?(:run_686_form_jobs)

      expect(claim.errors.attribute_names).to include(:parsed_form)
      expect(claim.errors[:parsed_form]).to include("SSN can't be blank")
    end

    it 'flags an error when dependent application data is not present' do
      claim.parsed_form.delete('dependents_application')
      claim.valid?(:run_686_form_jobs)

      expect(claim.errors.attribute_names).to include(:parsed_form)
      expect(claim.errors[:parsed_form]).to include("Dependent application can't be blank")
    end
  end

  context 'when determining document_type' do
    describe '#document_type' do
      it 'returns the correct document type' do
        expect(subject.document_type).to eq 148
      end
    end
  end

  context 'sending submitted email' do
    context 'when form 686 only' do
      subject { described_class.new(form: adopted_child.to_json) }

      it 'delivers a 686 submitted email' do
        notification_email = instance_double(Dependents::NotificationEmail)
        expect(Dependents::NotificationEmail)
          .to receive(:new).with(subject.id, nil)
          .and_return(notification_email)

        expect(notification_email).to receive(:deliver).with(:submitted686)
        expect(subject.monitor).to receive(:track_send_submitted_email_success).with(nil)

        subject.send_submitted_email(nil)
      end
    end

    context 'when form 674 only' do
      subject { described_class.new(form: form_674_only.to_json) }

      it 'delivers a 674 submitted email' do
        notification_email = instance_double(Dependents::NotificationEmail)
        expect(Dependents::NotificationEmail)
          .to receive(:new).with(subject.id, nil)
          .and_return(notification_email)

        expect(notification_email).to receive(:deliver).with(:submitted674)
        expect(subject.monitor).to receive(:track_send_submitted_email_success).with(nil)

        subject.send_submitted_email(nil)
      end
    end

    context 'when form 686 and 674' do
      subject { described_class.new(form: all_flows_payload.to_json) }

      it 'delivers a combo submitted email' do
        notification_email = instance_double(Dependents::NotificationEmail)
        expect(Dependents::NotificationEmail)
          .to receive(:new).with(subject.id, nil)
          .and_return(notification_email)

        expect(notification_email).to receive(:deliver).with(:submitted686c674)
        expect(subject.monitor).to receive(:track_send_submitted_email_success).with(nil)

        subject.send_submitted_email(nil)
      end
    end

    context 'when neither 686 nor 674 (an error)' do
      subject { described_class.new }

      it 'delivers a combo submitted email' do
        notification_email = instance_double(Dependents::NotificationEmail)
        expect(Dependents::NotificationEmail)
          .to receive(:new).with(subject.id, nil)
          .and_return(notification_email)

        expect(subject.monitor).to receive(:track_unknown_claim_type).with(kind_of(StandardError))
        expect(notification_email).to receive(:deliver).with(:submitted686c674)
        # Not sure why this is being done, but it is
        expect(subject.monitor).to receive(:track_send_submitted_email_success).with(nil)

        subject.send_submitted_email(nil)
      end
    end

    context 'when an error occurs while sending the email' do
      subject { described_class.new }

      let(:standard_error) { StandardError.new('test error') }

      before do
        allow(Dependents::NotificationEmail).to receive(:new).and_raise(standard_error)
      end

      it 'tracks the error' do
        expect(subject.monitor).to receive(:track_send_submitted_email_failure).with(standard_error, nil)
        subject.send_submitted_email(nil)
      end
    end
  end

  context 'sending received email' do
    context 'when form 686 only' do
      subject { described_class.new(form: adopted_child.to_json) }

      it 'delivers a 686 received email' do
        notification_email = instance_double(Dependents::NotificationEmail)
        expect(Dependents::NotificationEmail)
          .to receive(:new).with(subject.id, nil)
          .and_return(notification_email)

        expect(notification_email).to receive(:deliver).with(:received686)
        expect(subject.monitor).to receive(:track_send_received_email_success).with(nil)

        subject.send_received_email(nil)
      end
    end

    context 'when form 674 only' do
      subject { described_class.new(form: form_674_only.to_json) }

      it 'delivers a 674 received email' do
        notification_email = instance_double(Dependents::NotificationEmail)
        expect(Dependents::NotificationEmail)
          .to receive(:new).with(subject.id, nil)
          .and_return(notification_email)

        expect(notification_email).to receive(:deliver).with(:received674)
        expect(subject.monitor).to receive(:track_send_received_email_success).with(nil)

        subject.send_received_email(nil)
      end
    end

    context 'when form 686 and 674' do
      subject { described_class.new(form: all_flows_payload.to_json) }

      it 'delivers a combo received email' do
        notification_email = instance_double(Dependents::NotificationEmail)
        expect(Dependents::NotificationEmail)
          .to receive(:new).with(subject.id, nil)
          .and_return(notification_email)

        expect(notification_email).to receive(:deliver).with(:received686c674)
        expect(subject.monitor).to receive(:track_send_received_email_success).with(nil)

        subject.send_received_email(nil)
      end
    end

    context 'when neither 686 nor 674 (an error)' do
      subject { described_class.new }

      it 'delivers a combo received email' do
        notification_email = instance_double(Dependents::NotificationEmail)
        expect(Dependents::NotificationEmail)
          .to receive(:new).with(subject.id, nil)
          .and_return(notification_email)

        expect(subject.monitor).to receive(:track_unknown_claim_type).with(kind_of(StandardError))
        expect(notification_email).to receive(:deliver).with(:received686c674)
        # Not sure why this is being done, but it is
        expect(subject.monitor).to receive(:track_send_received_email_success).with(nil)

        subject.send_received_email(nil)
      end
    end

    context 'when an error occurs while sending the email' do
      subject { described_class.new }

      let(:standard_error) { StandardError.new('test error') }

      before do
        allow(Dependents::NotificationEmail).to receive(:new).and_raise(standard_error)
      end

      it 'tracks the error' do
        expect(subject.monitor).to receive(:track_send_received_email_failure).with(standard_error, nil)
        subject.send_received_email(nil)
      end
    end

    context 'when veteran_information is missing' do
      let(:no_veteran_claim) { create(:dependency_claim_no_vet_information) }

      before do
        allow(PdfFill::Filler).to receive(:fill_form).and_call_original

        subject_v2.parsed_form.delete('veteran_information')
        subject_v2.parsed_form['dependents_application'].delete('veteran_information')
      end

      it 'raises an error in the PDF filler' do
        expect { no_veteran_claim.to_pdf(form_id: '686C-674-V2') }.to raise_error(Dependents::ErrorClasses::MissingVeteranInfoError)
      end
    end
  end
end
