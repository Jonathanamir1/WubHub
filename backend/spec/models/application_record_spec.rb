require 'rails_helper'

RSpec.describe ApplicationRecord, type: :model do
  # Test the base class behaviors that all models inherit
  
  describe "database connection" do
    it "connects to the correct database" do
      expect(ApplicationRecord.connection).to be_present
      expect(ApplicationRecord.connection.adapter_name).to eq('PostgreSQL')
    end
  end

  describe "inheritance" do
  end

  describe "primary key configuration" do
    it "uses standard primary key configuration" do
      expect(ApplicationRecord.primary_key).to eq('id')
    end
  end
end
