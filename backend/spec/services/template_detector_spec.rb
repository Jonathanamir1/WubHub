require 'rails_helper'

RSpec.describe TemplateDetector, type: :service do
  describe '.detect_template' do
    
    it 'defaults to "other" when no template specified' do
      workspace = create(:workspace, template_type: nil)
      
      template = TemplateDetector.detect_template(workspace)
      
      expect(template).to eq('other')
    end

    it 'returns "other" for invalid template types' do
      workspace = create(:workspace, template_type: 'invalid_type')
      
      template = TemplateDetector.detect_template(workspace)
      
      expect(template).to eq('other')
    end

    it 'returns valid template types' do
      workspace = create(:workspace, template_type: 'producer')
      
      template = TemplateDetector.detect_template(workspace)
      
      expect(template).to eq('producer')
    end

    it 'handles empty template type gracefully' do
      workspace = create(:workspace, template_type: '')
      
      template = TemplateDetector.detect_template(workspace)
      
      expect(template).to eq('other')
    end
  end

  describe '.available_templates' do
    it 'returns all available template types' do
      templates = TemplateDetector.available_templates
      
      expect(templates).to include('songwriter', 'producer', 'mixing_engineer', 'mastering_engineer', 'artist', 'other')
      expect(templates.length).to eq(6)
    end
  end
end