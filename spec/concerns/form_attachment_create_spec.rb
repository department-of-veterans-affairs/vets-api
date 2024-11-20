# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormAttachmentCreate, type: :controller do
  shared_context 'stub controller' do
    before do
      stub_const('TestFormAttachmentCreate', controller_class)

      Rails.application.routes.draw do
        get 'test_form_attachment_create', to: 'test_form_attachment_create#create'
      end

      @controller = controller_class.new
    end
  end

  after do
    Rails.application.reload_routes!
  end

  describe '#create' do
    context 'with Sentry logging enabled' do
      let(:controller_class) do
        Class.new(ApplicationController) do
          include FormAttachmentCreate
          service_tag 'healthcare-application'

          skip_before_action :authenticate

          def form_attachment_model
            HCAAttachment
          end

          def serializer_klass
            HCAAttachmentSerializer
          end
        end
      end

      controller_class::FORM_ATTACHMENT_MODEL = HCAAttachment

      include_context 'stub controller'

      it 'validates and saves attachment' do
        file_data = Rack::Test::UploadedFile.new(Tempfile.new('banana.pdf'))

        expect(Flipper).to receive(:enabled?).with(:hca_log_form_attachment_create).twice.and_return(true)

        expect(@controller).to receive(:log_message_to_sentry).with(
          'begin form attachment creation',
          :info,
          file_data_present: true,
          klass: 'ActionDispatch::Http::UploadedFile',
          debug_timestamp: anything
        )
        expect(@controller).to receive(:log_message_to_sentry).with(
          'finish form attachment creation',
          :info,
          serialized: true,
          debug_timestamp: anything
        )

        form_attachment = double(HCAAttachment)
        expect(HCAAttachment).to receive(:new) { form_attachment }
        expect(form_attachment).to receive(:set_file_data!)
        expect(form_attachment).to receive(:save!)

        post(:create, params: { hca_attachment: { file_data: } })
      end

      it 'logs validation failure when attachment is not a type of UploadedFile' do
        file_data = 'foo'
        expect(Flipper).to receive(:enabled?).with(:hca_log_form_attachment_create).and_return(true)
        expect(@controller).to receive(:log_message_to_sentry).with(
          'begin form attachment creation',
          :info,
          file_data_present: true,
          klass: 'String',
          debug_timestamp: anything
        )
        expect(@controller).to receive(:log_message_to_sentry).with(
          'form attachment error 1 - validate class',
          :info,
          phase: 'FAC_validate',
          klass: 'String',
          exception: 'Invalid field value'
        )
        post(:create, params: { hca_attachment: { file_data: } })
      end

      it 'logs failure to save to cloud' do
        file_data = Rack::Test::UploadedFile.new(Tempfile.new('banana.pdf'))

        expect(Flipper).to receive(:enabled?).with(:hca_log_form_attachment_create).and_return(true)

        expect(@controller).to receive(:log_message_to_sentry).with(
          'begin form attachment creation',
          :info,
          file_data_present: true,
          klass: 'ActionDispatch::Http::UploadedFile',
          debug_timestamp: anything
        )
        expect(@controller).to receive(:log_message_to_sentry).with(
          'form attachment error 2 - save to cloud',
          :info,
          has_pass: false,
          ext: File.extname(file_data).last(5),
          phase: 'FAC_cloud',
          exception: 'Unprocessable Entity'
        )

        form_attachment = double(HCAAttachment)
        expect(HCAAttachment).to receive(:new) { form_attachment }
        expect(form_attachment).to receive(:set_file_data!).and_raise(Common::Exceptions::UnprocessableEntity)

        post(:create, params: { hca_attachment: { file_data: } })
      end

      it 'logs failure to save to db' do
        file_data = Rack::Test::UploadedFile.new(Tempfile.new('banana.pdf'))

        expect(Flipper).to receive(:enabled?).with(:hca_log_form_attachment_create).and_return(true)

        expect(@controller).to receive(:log_message_to_sentry).with(
          'begin form attachment creation',
          :info,
          file_data_present: true,
          klass: 'ActionDispatch::Http::UploadedFile',
          debug_timestamp: anything
        )
        expect(@controller).to receive(:log_message_to_sentry).with(
          'form attachment error 3 - save to db',
          :info,
          phase: 'FAC_db',
          errors: 'error text',
          exception: 'Record invalid'
        )

        form_attachment = double(HCAAttachment)
        expect(HCAAttachment).to receive(:new) { form_attachment }
        expect(form_attachment).to receive(:set_file_data!)
        expect(form_attachment).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)
        expect(form_attachment).to receive(:errors).and_return('error text')

        post(:create, params: { hca_attachment: { file_data: } })
      end
    end
  end
end
