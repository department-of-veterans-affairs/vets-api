# frozen_string_literal: true

BGS_ERRORS = [
  Common::Exceptions::ResourceNotFound,
  Common::Exceptions::ServiceError,
  Common::Exceptions::UnprocessableEntity,
  ActiveRecord::RecordNotFound
].freeze

# helper to validate error handling for BGS service exceptions
# rubocop:disable Metrics/MethodLength, Metrics/AbcSize
def validate_bgs_service_error_handling(service_class, method_name, use_instance_double: false)
  BGS_ERRORS.each do |bgs_error|
    context "with a #{bgs_error} raised from the BGS service" do
      let(:error_detail) { 'Specific SOAP error detail message' }
      let(:raised_error) do
        if bgs_error.ancestors.include?(Common::Exceptions::BaseError)
          bgs_error.new(detail: error_detail)
        else
          bgs_error.new(error_detail)
        end
      end

      before do
        if use_instance_double
          case service_class.name
          when 'ClaimsApi::PersonWebService'
            allow(person_web_service).to receive(method_name).and_raise(raised_error)
          when 'ClaimsApi::ManageRepresentativeService'
            allow(manage_rep_poa_update_service).to receive(method_name).and_raise(raised_error)
          end
        else
          allow_any_instance_of(service_class).to receive(method_name).and_raise(raised_error)
        end
      end

      it "updates the form's status and does not create a 'ClaimsApi::PoaVBMSUpdater' job" do
        expect(ClaimsApi::PoaVBMSUpdater).not_to receive(:perform_async)
        expect { subject.new.perform(poa.id) }.to raise_error(bgs_error)
        # For ActiveRecord::RecordNotFound, the POA won't be found to check status
        unless bgs_error == ActiveRecord::RecordNotFound
          poa.reload
          expect(poa.status).to eq('errored')
        end
      end

      it 'updates the process status to FAILED and returns the error detail' do
        expect { subject.new.perform(poa.id) }.to raise_error(bgs_error)
        # For ActiveRecord::RecordNotFound, process won't be created if POA not found
        unless bgs_error == ActiveRecord::RecordNotFound
          process = ClaimsApi::Process.find_by(processable: poa, step_type: 'POA_UPDATE')
          expect(process.step_status).to eq('FAILED')
          expect(process.error_messages.first['title']).to eq('BGS Error')
          # For Common::Exceptions::*, the detail should be extracted from errors.first.detail
          # For other exceptions, it should be the message
          expect(process.error_messages.first['detail']).to eq(error_detail)
        end
      end

      it 'sets vbms_error_message with the error detail' do
        expect { subject.new.perform(poa.id) }.to raise_error(bgs_error)
        # For ActiveRecord::RecordNotFound, POA won't be found
        unless bgs_error == ActiveRecord::RecordNotFound
          poa.reload
          # vbms_error_message should contain the specific error detail, not just the i18n title
          expect(poa.vbms_error_message).to eq(error_detail)
        end
      end
    end
  end
end

# helper to validate error handling for StandardError exceptions
def validate_standard_error_handling(service_class, method_name, use_instance_double: false)
  context 'with a StandardError that is not from the BGS Service' do
    let(:standard_error) { StandardError }

    before do
      if use_instance_double
        case service_class.name
        when 'ClaimsApi::PersonWebService'
          allow(person_web_service).to receive(method_name).and_raise(standard_error)
        when 'ClaimsApi::ManageRepresentativeService'
          allow(manage_rep_poa_update_service).to receive(method_name).and_raise(standard_error)
        end
      else
        allow_any_instance_of(service_class).to receive(method_name).and_raise(standard_error)
      end
    end

    it "updates the form's status and does not create a 'ClaimsApi::PoaVBMSUpdater' job" do
      expect(ClaimsApi::PoaVBMSUpdater).not_to receive(:perform_async)
      expect { subject.new.perform(poa.id) }.to raise_error(standard_error)
      poa.reload
      expect(poa.status).to eq('errored')
    end

    it 'updates the process status to FAILED and returns the error message' do
      expect { subject.new.perform(poa.id) }.to raise_error(standard_error)
      process = ClaimsApi::Process.find_by(processable: poa, step_type: 'POA_UPDATE')
      expect(process.step_status).to eq('FAILED')
      expect(process.error_messages.first['title']).to eq('Generic Error')
      expect(process.error_messages.first['detail']).to eq(standard_error.new.message)
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize
