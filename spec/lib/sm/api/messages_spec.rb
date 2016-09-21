# frozen_string_literal: true
describe SM::Client do
  let(:config) { SM::Configuration.new(attributes_for(:configuration)) }
  let(:session) { SM::ClientSession.new(attributes_for(:session, :valid_user)) }

  before(:each) do
    @client = SM::Client.new(config: config, session: session)
  end

  describe 'get_message' do
    context 'with valid id' do
      let(:id) { 573_302 }
      let(:message_subj) { 'Release 16.2- SM last login' }

      before(:each) do
        VCR.use_cassette('sm/messages/10616687/show') do
          @client.authenticate
          @msg = @client.get_message(id)
        end
      end

      it 'gets a message by message id' do
        expect(@msg.attributes[:id]).to eq(id)
        expect(@msg.attributes[:subject].strip).to eq(message_subj)
      end

      it 'marks a message read' do
        expect(@msg.attributes[:read_receipt]).to eq('READ')
      end
    end
  end

  describe 'get_message_history' do
    context 'with valid id' do
      # Note history does not seem to work with a new message and new replay
      let(:id) { 573_059 }

      before(:each) do
        VCR.use_cassette('sm/messages/10616687/thread') do
          @client.authenticate
          @history = @client.get_message_history(id)
        end
      end

      it 'gets a message by message id' do
        expect(@history.data.class).to eq(Array)
        expect(@history.data.size).to eq(2)
      end
    end
  end

  describe 'get_message_category' do
    before(:each) do
      VCR.use_cassette('sm/messages/10616687/category') do
        @client.authenticate
        @category = @client.get_message_category
      end
    end

    it 'retrieves an array of categories' do
      expect(@category).to be_a(Category)
      expect(@category.message_category_type).to contain_exactly(
        'OTHER', 'APPOINTMENTS', 'MEDICATIONS', 'TEST_RESULTS', 'EDUCATION'
      )
    end
  end

  describe 'post_create_message_draft' do
    let(:new_draft) do
      attributes_for(:message)
        .except(:id, :attachment, :sent_date, :sender_id, :sender_name, :recipient_name, :read_receipt)
    end

    context 'with valid attributes' do
      it 'creates a new draft without attachments' do
        VCR.use_cassette('sm/messages/10616687/create_draft') do
          @client.authenticate
          @msg = @client.post_create_message_draft(new_draft)
        end

        expect(@msg.attributes.keys).to contain_exactly(
          :id, :category, :subject, :body, :attachment, :sent_date, :sender_id, :sender_name, :recipient_id,
          :recipient_name, :read_receipt
        )
      end

      it 'updates an existing draft' do
        VCR.use_cassette('sm/messages/10616687/update_draft') do
          @client.authenticate
          draft = @client.post_create_message_draft(new_draft)

          new_draft[:id] = draft.id
          new_draft[:body] = draft.body + ' Now has been updated'

          @msg = @client.post_create_message_draft(new_draft)
        end

        expect(@msg.attributes.keys).to contain_exactly(
          :id, :category, :subject, :body, :attachment, :sent_date, :sender_id, :sender_name, :recipient_id,
          :recipient_name, :read_receipt
        )
      end
    end
  end

  describe 'post_create_message' do
    let(:new_message) do
      attributes_for(:message)
        .except(:id, :attachment, :sent_date, :sender_id, :sender_name, :recipient_name, :read_receipt)
    end

    context 'with valid attributes' do
      it 'creates and sends a new message without attachments' do
        VCR.use_cassette('sm/messages/10616687/create') do
          @client.authenticate
          @msg = @client.post_create_message(new_message)
        end

        expect(@msg.attributes.keys).to contain_exactly(
          :id, :category, :subject, :body, :attachment, :sent_date, :sender_id, :sender_name, :recipient_id,
          :recipient_name, :read_receipt
        )
      end

      it 'sends a draft message without attachments' do
        VCR.use_cassette('sm/messages/10616687/create_message_from_draft') do
          @client.authenticate
          draft_msg = @client.post_create_message_draft(new_message)
          new_message[:id] = draft_msg.id

          @msg = @client.post_create_message(new_message)
        end

        expect(@msg.attributes.keys).to contain_exactly(
          :id, :category, :subject, :body, :attachment, :sent_date, :sender_id, :sender_name, :recipient_id,
          :recipient_name, :read_receipt
        )
      end
    end
  end

  describe 'post_create_message_reply' do
    let(:new_message) do
      attributes_for(:message)
        .except(:id, :attachment, :sent_date, :sender_id, :sender_name, :recipient_name, :read_receipt)
    end

    context 'with a non-draft reply with valid attributes and without attachements' do
      let(:reply_body) { 'This is a reply body' }

      it 'replies to a message by id' do
        VCR.use_cassette('sm/messages/10616687/create_message_reply') do
          @client.authenticate

          @msg = @client.post_create_message(new_message)
          @reply = @client.post_create_message_reply(id: @msg.id, body: reply_body)
        end
      end
    end
  end

  describe 'delete_message' do
    let(:msg_id) { 573_034 }

    context 'with valid id' do
      it 'deletes the message' do
        VCR.use_cassette('sm/messages/10616687/delete') do
          @client.authenticate
          @status = @client.delete_message(msg_id)
        end

        expect(@status).to eq(200)
      end
    end
  end
end
