# frozen_string_literal: true

module MyHealth
  module V1
    class VaccinesController < MrController
      def index
        patient_id = params[:patient_id]
        resource = client.list_vaccines(patient_id)
        raise Common::Exceptions::InternalServerError if resource.blank?

        render json: resource.to_json
      end

      def show
        vaccine_id = params[:id].try(:to_i)
        resource = client.get_vaccine(vaccine_id)
        raise Common::Exceptions::InternalServerError if resource.blank?

        render json: resource.to_json
      end

      def pdf
        vaccine_id = params[:id]
        vaccines_list = vaccine_id ? [1] : [*0...9]
        filename = vaccine_id ? 'tmp/vaccine.pdf' : 'tmp/vaccines.pdf'

        MyHealth::PdfConstruction::Generator.new(filename, vaccines_list).make_vaccines_pdf

        pdf_file = File.open(filename)
        base64 = Base64.encode64(pdf_file.read)
        response = { pdf: base64 }
        render json: response
      end
    end
  end
end
