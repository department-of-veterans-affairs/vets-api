# frozen_string_literal: true

require 'json'

module SimpleFormsApi
  class VBA4010007
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('application', 'claimant', 'name', 'first'),
        'veteranLastName' => @data.dig('application', 'claimant', 'name', 'last'),
        'fileNumber' => @data.dig('application', 'claimant', 'ssn')&.gsub('-', ''),
        'zipCode' => @data.dig('application', 'claimant', 'address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'NCA'
      }
    end

    def handle_attachments(file_path)
      attachments = get_attachments
      if attachments.count.positive?
        combined_pdf = CombinePDF.new
        combined_pdf << CombinePDF.load(file_path)
        attachments.each do |attachment|
          combined_pdf << CombinePDF.load(attachment)
        end
        combined_pdf.save file_path
      end
    end

    def service(num, field, date)
      service_records = data.dig('application', 'veteran', 'service_records')

      return '' if service_records.nil? || service_records[num].nil?

      value = if date
                service_records[num][field]&.[](date)
              else
                service_records[num][field]
              end

      value.to_s # Convert nil to an empty string
    end

    def find_cemetery_by_id(cemetery_id)
      file_path = 'modules/simple_forms_api/app/json/cemeteries.json'
      file_content = File.read(file_path)
      cemeteries = JSON.parse(file_content)

      cemetery = cemeteries['data']&.find do |entry|
        entry['attributes']&.dig('cemetery_id') == cemetery_id
      end

      if cemetery
        cemetery['attributes']['name']
      else
        'Cemetery not found.'
      end
    end

    def track_user_identity(confirmation_number); end

    def submission_date_config
      { should_stamp_date?: false }
    end

    private

    def get_attachments
      attachments = []

      supporting_documents = @data['application']['preneed_attachments']
      if supporting_documents
        confirmation_codes = []
        supporting_documents&.map { |doc| confirmation_codes << doc['confirmation_code'] }

        PersistentAttachment.where(guid: confirmation_codes).map { |attachment| attachments << attachment.to_pdf }
      end
      attachments
    end
  end
end
