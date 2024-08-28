# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Preneeds::BurialForm', type: :request do
  include SchemaMatchers

  let(:params) do
    { application: attributes_for(:burial_form) }
  end

  def post_burial_forms(additional_headers = {})
    post '/v0/preneeds/burial_forms',
         params: params.to_json,
         headers: { 'CONTENT_TYPE' => 'application/json' }.merge(additional_headers)
  end

  context 'with invalid input' do
    it 'returns an with error' do
      params[:application][:veteran].delete(:military_status)
      post_burial_forms

      error = JSON.parse(response.body)['errors'].first

      expect(error['status']).to eq('422')
      expect(error['title']).to match(/validation error/i)
      expect(error['detail']).to match(/militaryStatus/)
    end

    it 'does not clear the saved form' do
      expect_any_instance_of(ApplicationController).not_to receive(:clear_saved_form).with('40-10007')

      params[:application][:veteran].delete(:military_status)
      post_burial_forms
    end
  end

  context 'with a failed burial form submittal from EOAS' do
    it 'returns with a VA900 error when status is 500' do
      VCR.use_cassette('preneeds/burial_forms/burial_form_with_invalid_applicant_address2') do
        params[:application][:applicant][:mailing_address][:address2] = '1' * 21
        post_burial_forms
      end

      error = JSON.parse(response.body)['errors'].first

      expect(error['status']).to eq('400')
      expect(error['title']).to match(/operation failed/i)
      expect(error['detail']).to match(/Error committing transaction/i)
    end

    it 'returns with a VA900 error when the status is 200' do
      VCR.use_cassette('preneeds/burial_forms/burial_form_with_duplicate_tracking_number') do
        allow_any_instance_of(Preneeds::BurialForm).to receive(:generate_tracking_number).and_return('19')
        post_burial_forms
      end

      error = JSON.parse(response.body)['errors'].first

      expect(error['status']).to eq('400')
      expect(error['title']).to match(/operation failed/i)
      expect(error['detail']).to match(/Tracking number '19' already exists/i)
    end

    it 'does not clear the saved form' do
      expect_any_instance_of(ApplicationController).not_to receive(:clear_saved_form).with('40-10007')

      VCR.use_cassette('preneeds/burial_forms/burial_form_with_duplicate_tracking_number') do
        allow_any_instance_of(Preneeds::BurialForm).to receive(:generate_tracking_number).and_return('19')
        post_burial_forms
      end
    end
  end

  describe '#send_confirmation_email' do
    subject { V0::Preneeds::BurialFormsController.new }

    let(:submission_record) { OpenStruct.new(application_uuid: 'UUID') }
    let(:form) do
      Preneeds::BurialForm.new(params).tap do |f|
        f.claimant = Preneeds::Claimant.new(
          email: 'foo@foo.com',
          name: Preneeds::FullName.new(
            first: 'Derrick',
            last: 'Last'
          )
        )
        f.applicant = Preneeds::Applicant.new(
          applicant_relationship_to_claimant: 'Self',
          applicant_email: 'bar@bar.com',
          name: Preneeds::FullName.new(
            first: 'Applicant',
            last: 'Last'
          )
        )
      end
    end

    it 'calls the send email job with the correct parameters' do
      expect(VANotify::EmailJob).to receive(:perform_async).with(
        'foo@foo.com',
        'preneeds_burial_form_email_template_id',
        {
          'form_name' => 'Burial Pre-Need (Form 40-10007)',
          'applicant_1_first_name_last_initial' => 'Applicant L',
          'confirmation_number' => 'UUID',
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
          'first_name' => 'APPLICANT'
        }
      )

      subject.instance_variable_set(:@form, form)
      subject.instance_variable_set(:@resource, submission_record)
      subject.send_confirmation_email
    end
  end
end
