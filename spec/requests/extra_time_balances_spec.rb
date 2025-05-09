require 'rails_helper'

RSpec.describe "ExtraTimeBalances", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/extra_time_balances/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/extra_time_balances/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/extra_time_balances/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get "/extra_time_balances/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/extra_time_balances/update"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/extra_time_balances/destroy"
      expect(response).to have_http_status(:success)
    end
  end

end
