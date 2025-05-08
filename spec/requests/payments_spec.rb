require 'rails_helper'

RSpec.describe "Payments", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/payments/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/payments/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/payments/create"
      expect(response).to have_http_status(:success)
    end
  end

end
