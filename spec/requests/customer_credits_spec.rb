require 'rails_helper'

RSpec.describe "CustomerCredits", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/customer_credits/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/customer_credits/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/customer_credits/create"
      expect(response).to have_http_status(:success)
    end
  end

end
