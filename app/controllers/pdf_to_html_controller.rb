class PdfToHtmlController < ApplicationController
  def convert
    if params[:pdf].present?
      pdf_file = params[:pdf]

      service = PdfToHtmlService.new(pdf_file)
      html_file_path = service.convert

      render json: { message: "Conversion successful", html_file: html_file_path }, status: :ok
    else
      render json: { error: "No PDF file provided" }, status: :unprocessable_entity
    end
  end
end
