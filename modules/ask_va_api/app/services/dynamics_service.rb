# frozen_string_literal: true

class DynamicsService
  DATA = [
    {
      'inquiryNumber' => 'A-1',
      'inquiryTopic' => 'Topic',
      'submitterQuestions' => 'This is a question',
      'inquiryProcessingStatus' => 'In Progress',
      'lastUpdate' => '08/07/23',
      'userUuid' => '6400bbf301eb4e6e95ccea7693eced6f'
    },
    {
      'inquiryNumber' => 'A-2',
      'inquiryTopic' => 'Topic',
      'submitterQuestions' => 'This is a question',
      'inquiryProcessingStatus' => 'In Progress',
      'lastUpdate' => '08/07/23',
      'userUuid' => '6400bbf301eb4e6e95ccea7693eced6f'
    }
  ].freeze

  def get_submitter_inquiries(uuid:)
    inquiries = DATA.filter_map do |inquiry|
      AskVAApi::Inquiry::Creator.new(inquiry) if inquiry['userUuid'] == uuid
    end

    AskVAApi::UserInquiries::Creator.new(inquiries)
  end
end
