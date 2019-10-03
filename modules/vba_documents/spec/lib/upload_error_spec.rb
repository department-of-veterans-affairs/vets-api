# frozen_string_literal: true

require 'rails_helper'
require 'vba_documents/upload_error'

RSpec.describe VBADocuments::UploadError do
  describe 'Notifing StatsD on upload Error' do
    it 'makes a call to stadsd on initilize' do
      expect(StatsD).to receive(:increment)
      VBADocuments::UploadError.new(code: 'DOC103')
    end
  end
end
