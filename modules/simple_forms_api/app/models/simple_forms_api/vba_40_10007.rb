# frozen_string_literal: true

module SimpleFormsApi
  class VBA4010007
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

    def metadata
      {
        # 'veteranFirstName' => @data.dig('veteran', 'full_name', 'first'),
        # 'veteranLastName' => @data.dig('veteran', 'full_name', 'last'),
        # 'fileNumber' => @data.dig('veteran', 'va_file_number').presence || @data.dig('veteran', 'ssn'),
        # 'zipCode' => @data.dig('veteran', 'address', 'postal_code'),
        # 'source' => 'VA Platform Digital Forms',
        # 'docType' => @data['form_number'],
        # 'businessLine' => 'CMP'
      }
    end
    def service(num, field, date)
      service_records = data.dig("application", "veteran", "service_records")
      if service_records
        if date
          return service_records[num][field][date]
        else
          return service_records[num][field] 
        end
      else
        return ''
      end
    end

    def currently_buried(num, field)
      name = data.dig("application", "applicant", "currently_buried_persons")
      if name
          return name[num]["name"][field] 
      else
        return ''
      end
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

    private

    def get_attachments
      attachments = []
      supporting_documents = @data['preneed_attachments']
   
      if supporting_documents
        confirmation_codes = []
        supporting_documents&.map { |doc| confirmation_codes << doc['confirmation_code'] }

        PersistentAttachment.where(guid: confirmation_codes).map { |attachment| attachments << attachment.to_pdf }
      end

      attachments
    end       
  end
end
