# frozen_string_literal: true

Rails.application.routes.draw do
  scope '/services' do
    mount VBADocuments::Engine => '/vba_documents'
  end
end
