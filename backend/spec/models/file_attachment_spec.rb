require 'rails_helper'

RSpec.describe FileAttachment, type: :model do
  describe 'validations' do
    it 'requires filename to be present' do
      file_attachment = FileAttachment.new(filename: nil)
      expect(file_attachment).not_to be_valid
      expect(file_attachment.errors[:filename]).to include("can't be blank")
    end
  end
end