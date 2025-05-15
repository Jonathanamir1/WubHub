require 'rails_helper'

RSpec.describe "Api::V1::Auths", type: :request do
  describe "GET /login" do
    it "returns http success" do
      get "/api/v1/auth/login"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /register" do
    it "returns http success" do
      get "/api/v1/auth/register"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /current" do
    it "returns http success" do
      get "/api/v1/auth/current"
      expect(response).to have_http_status(:success)
    end
  end

end
