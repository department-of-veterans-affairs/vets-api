# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

describe 'sm client' do
  describe 'messages' do
    before do
      VCR.use_cassette 'sm_client/session' do
        @client ||= begin
          client = SM::Client.new(session: { user_id: '10616687' })
          client.authenticate
          client
        end
      end
    end

    let(:client)              { @client }
    let(:existing_message_id) { 573_059 }
    let(:move_message_id)     { 573_052 }
    let(:destroy_message_id)  { 573_052 }
    let(:existing_folder_id)  { 610_965 }

    it 'raises an error when a service outage exists', :vcr do
      SM::Configuration.instance.breakers_service.begin_forced_outage!
      expect { client.get_message(existing_message_id) }
        .to raise_error(Breakers::OutageException)
      SM::Configuration.instance.breakers_service.end_forced_outage!
    end

    it 'deletes the message with id', :vcr do
      expect(client.delete_message(destroy_message_id)).to eq(200)
    end

    # Move the previously deleted message back to the inbox
    it 'moves a message with id', :vcr do
      expect(client.post_move_message(move_message_id, 0)).to eq(200)
    end

    it 'gets a message with id', :vcr do
      message = client.get_message(existing_message_id)
      expect(message.id).to eq(existing_message_id)
      expect(message.subject).to eq('Quote test: “test”')
    end

    it 'gets a message thread', :vcr do
      thread = client.get_message_history(existing_message_id)
      expect(thread).to be_a(Vets::Collection)
      expect(thread.members.size).to eq(2)
    end

    it 'gets message categories', :vcr do
      categories = client.get_categories
      expect(categories).to be_a(Category)
      expect(categories.message_category_type).to contain_exactly(
        'OTHER', 'APPOINTMENTS', 'MEDICATIONS', 'TEST_RESULTS', 'EDUCATION'
      )
    end

    context 'creates' do
      before do
        VCR.use_cassette 'sm_client/messages/creates/a_new_message_without_attachments' do
          message_attributes = attributes_for(:message, subject: 'CI Run', body: 'Continuous Integration')
          @params = message_attributes.slice(:subject, :category, :recipient_id, :body)
          @created_message = @client.post_create_message(@params)
        end
      end

      let(:created_message)       { @created_message }
      let(:attachment_type)       { 'image/jpg' }
      let(:uploads) do
        filenames = %w[
          spec/fixtures/files/sm_file1.jpg
          spec/fixtures/files/sm_file2.jpg
          spec/fixtures/files/sm_file3.jpg
          spec/fixtures/files/sm_file4.jpg
        ]

        filenames.map do |path|
          tempfile = File.open(path)
          ActionDispatch::Http::UploadedFile.new(
            filename: File.basename(path),
            type: attachment_type,
            tempfile:
          )
        end
      end
      let(:params) { @params }
      let(:params_with_attachments) { { message: params }.merge(uploads:) }

      it 'a new message without attachments' do
        expect(created_message).to be_a(Message)
      end

      it 'a reply without attachments', :vcr do
        reply_message = client.post_create_message_reply(created_message.id, params)
        expect(reply_message).to be_a(Message)
      end

      it 'a new message with 4 attachments', :vcr do
        message = client.post_create_message_with_attachment(params_with_attachments)

        expect(message).to be_a(Message)
        expect(message.attachments.size).to eq(4)
        expect(message.attachments[0]).to be_an(Attachment)
      end

      it 'a reply with 4 attachments', :vcr do
        message = client.post_create_message_reply_with_attachment(created_message.id, params_with_attachments)

        expect(message).to be_a(Message)
        expect(message.attachments.size).to eq(4)
        expect(message.attachments[0]).to be_an(Attachment)
      end

      it 'cannot send reply draft as message', :vcr do
        draft = attributes_for(:message_draft, id: 655_623).slice(:id, :subject, :body, :recipient_id)
        expect { client.post_create_message(draft) }.to raise_error(Common::Exceptions::ValidationErrors)
      end

      it 'cannot send draft as reply', :vcr do
        draft = attributes_for(:message_draft, id: 655_626).slice(:id, :subject, :body, :recipient_id)
        expect { client.post_create_message_reply(631_270, draft) }.to raise_error(Common::Exceptions::ValidationErrors)
      end
    end

    context 'nested resources' do
      let(:message_id)    { 629_999 }
      let(:attachment_id) { 629_993 }

      it 'gets a single attachment by id', :vcr do
        attachment = client.get_attachment(message_id, attachment_id)

        expect(attachment[:filename]).to eq('noise300x200.png')
        expect(attachment[:body].encoding.to_s).to eq('ASCII-8BIT')
      end

      it 'gets a single attachment with quotes in filename', :vcr do
        attachment = client.get_attachment(message_id, attachment_id)
        expect(attachment[:filename]).to eq('noise300x200.png')
      end
    end

    context 'get_attachment method' do
      let(:message_id) { 123 }
      let(:attachment_id) { 456 }
      let(:client) { SM::Client.new(session: { user_id: '10616687' }) }

      before do
        allow(client).to receive(:token_headers).and_return({})
      end

      context 'when response contains object with URL details' do
        let(:mock_response) do
          double('response',
                 body: { data: { url: 'https://s3.amazonaws.com/bucket/file.pdf', mime_type: 'application/pdf',
                                 name: 'document.pdf' } },
                 response_headers: {})
        end
        let(:file_content) { 'PDF file content' }
        let(:file_response) { double('file_response', body: file_content) }
        let(:http_client) { double('http_client') }

        before do
          allow(client).to receive(:perform).and_return(mock_response)
          allow(Net::HTTP).to receive(:start).and_yield(http_client)
          allow(http_client).to receive(:get).and_return(file_response)
          allow(file_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        end

        it 'fetches file from URL and uses name from object' do
          result = client.get_attachment(message_id, attachment_id)

          expect(result[:body]).to eq(file_content)
          expect(result[:filename]).to eq('document.pdf')
        end

        it 'makes HTTP request to the presigned URL' do
          expect(Net::HTTP).to receive(:start).with('s3.amazonaws.com', 443, use_ssl: true)

          client.get_attachment(message_id, attachment_id)
        end
      end

      context 'when response contains object with URL details but HTTP request fails' do
        let(:mock_response) do
          double('response',
                 body: { data: { url: 'https://s3.amazonaws.com/bucket/file.pdf', mime_type: 'application/pdf',
                                 name: 'document.pdf' } },
                 response_headers: {})
        end
        let(:file_response) { double('file_response', body: 'Not Found', code: '404') }
        let(:http_client) { double('http_client') }

        before do
          allow(client).to receive(:perform).and_return(mock_response)
          allow(Net::HTTP).to receive(:start).and_yield(http_client)
          allow(http_client).to receive(:get).and_return(file_response)
          allow(file_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
          allow(Rails.logger).to receive(:error)
        end

        it 'raises an exception when file fetch fails' do
          expect { client.get_attachment(message_id, attachment_id) }
            .to raise_error(Common::Exceptions::BackendServiceException)
        end

        it 'logs the error' do
          expect(Rails.logger).to receive(:error).with(/Failed to fetch attachment from presigned URL/)

          expect { client.get_attachment(message_id, attachment_id) }
            .to raise_error(Common::Exceptions::BackendServiceException)
        end
      end

      context 'when response is binary file (fallback)' do
        let(:binary_content) { 'binary file content' }
        let(:mock_response) do
          double('response',
                 body: binary_content,
                 response_headers: { 'content-disposition' => 'attachment; filename="test.pdf"' })
        end

        before do
          allow(client).to receive(:perform).and_return(mock_response)
        end

        it 'processes as binary file and extracts filename from headers' do
          result = client.get_attachment(message_id, attachment_id)

          expect(result[:body]).to eq(binary_content)
          expect(result[:filename]).to eq('test.pdf')
        end
      end

      context 'when response body is a Hash but missing required fields' do
        let(:binary_content) { 'fallback binary content' }
        let(:mock_response) do
          double('response',
                 body: { data: { url: 'https://example.com', mime_type: 'application/pdf' } }, # missing 'name'
                 response_headers: { 'content-disposition' => 'attachment; filename="fallback.pdf"' })
        end

        before do
          allow(client).to receive(:perform).and_return(mock_response)
        end

        it 'falls back to binary processing when object is incomplete' do
          result = client.get_attachment(message_id, attachment_id)

          expect(result[:body]).to eq({ data: { url: 'https://example.com', mime_type: 'application/pdf' } })
          expect(result[:filename]).to eq('fallback.pdf')
        end
      end

      context 'when response body is not a Hash' do
        let(:string_content) { 'direct string response' }
        let(:mock_response) do
          double('response',
                 body: string_content,
                 response_headers: { 'content-disposition' => 'attachment; filename="direct.txt"' })
        end

        before do
          allow(client).to receive(:perform).and_return(mock_response)
        end

        it 'processes as binary file response' do
          result = client.get_attachment(message_id, attachment_id)

          expect(result[:body]).to eq(string_content)
          expect(result[:filename]).to eq('direct.txt')
        end
      end

      context 'when content-disposition header has quotes' do
        let(:binary_content) { 'binary content' }
        let(:mock_response) do
          double('response',
                 body: binary_content,
                 response_headers: { 'content-disposition' => 'attachment; filename="quoted-file.pdf"' })
        end

        before do
          allow(client).to receive(:perform).and_return(mock_response)
        end

        it 'removes quotes from filename' do
          result = client.get_attachment(message_id, attachment_id)

          expect(result[:filename]).to eq('quoted-file.pdf')
        end
      end

      context 'when content-disposition header has %22 encoded quotes' do
        let(:binary_content) { 'binary content' }
        let(:mock_response) do
          double('response',
                 body: binary_content,
                 response_headers: { 'content-disposition' => 'attachment; filename=%22encoded-file.pdf%22' })
        end

        before do
          allow(client).to receive(:perform).and_return(mock_response)
        end

        it 'removes encoded quotes from filename' do
          result = client.get_attachment(message_id, attachment_id)

          expect(result[:filename]).to eq('encoded-file.pdf')
        end
      end
    end
  end
end
