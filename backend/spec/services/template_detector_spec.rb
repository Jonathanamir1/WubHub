# This should completely replace spec/services/template_detector_spec.rb

require 'rails_helper'

RSpec.describe TemplateDetector, type: :service do
  describe '.detect_template' do
    
    it 'defaults to "library" when no workspace provided' do
      template = TemplateDetector.detect_template(nil)
      expect(template).to eq('library')
    end
    
    it 'defaults to "library" when workspace_type is nil' do
      workspace = create(:workspace, workspace_type: 'project_based')
      workspace.update_column(:workspace_type, nil)  # Bypass validation for test
      
      template = TemplateDetector.detect_template(workspace)
      expect(template).to eq('library')
    end

    it 'defaults to "library" when workspace_type is empty' do
      workspace = create(:workspace, workspace_type: 'project_based')
      workspace.update_column(:workspace_type, '')  # Bypass validation for test
      
      template = TemplateDetector.detect_template(workspace)
      expect(template).to eq('library')
    end

    it 'returns "library" for invalid template types' do
      workspace = create(:workspace, workspace_type: 'project_based')
      workspace.update_column(:workspace_type, 'invalid_type')  # Bypass validation for test
      
      template = TemplateDetector.detect_template(workspace)
      expect(template).to eq('library')
    end

    it 'returns valid template types correctly' do
      %w[project_based client_based library].each do |type|
        workspace = create(:workspace, workspace_type: type)
        template = TemplateDetector.detect_template(workspace)
        expect(template).to eq(type)
      end
    end
  end

  describe '.available_templates' do
    it 'returns all available template types' do
      templates = TemplateDetector.available_templates
      
      expect(templates).to include('project_based', 'client_based', 'library')
      expect(templates.length).to eq(3)
    end
    
    it 'returns a copy of the array (not the original)' do
      templates1 = TemplateDetector.available_templates
      templates2 = TemplateDetector.available_templates
      
      expect(templates1).to eq(templates2)
      expect(templates1.object_id).not_to eq(templates2.object_id)
    end
  end
  
  describe '.template_info' do
    it 'returns info for project_based template' do
      info = TemplateDetector.template_info('project_based')
      
      expect(info[:name]).to eq('Project-Based')
      expect(info[:description]).to include('music projects')
      expect(info[:icon]).to eq('🎵')
      expect(info[:structure]).to be_an(Array)
      expect(info[:structure]).to include('Album Projects')
    end
    
    it 'returns info for client_based template' do
      info = TemplateDetector.template_info('client_based')
      
      expect(info[:name]).to eq('Client-Based')
      expect(info[:description]).to include('clients')
      expect(info[:icon]).to eq('🏢')
      expect(info[:structure]).to include('Client Name/Project Name')
    end
    
    it 'returns info for library template' do
      info = TemplateDetector.template_info('library')
      
      expect(info[:name]).to eq('Library Collection')
      expect(info[:description]).to include('samples')
      expect(info[:icon]).to eq('📚')
      expect(info[:structure]).to include('Sample Packs')
    end
    
    it 'handles unknown template types' do
      info = TemplateDetector.template_info('unknown')
      
      expect(info[:name]).to eq('Unknown')
      expect(info[:icon]).to eq('❓')
      expect(info[:structure]).to be_empty
    end
  end
  
  describe '.valid_template?' do
    it 'returns true for valid templates' do
      %w[project_based client_based library].each do |type|
        expect(TemplateDetector.valid_template?(type)).to be true
      end
    end
    
    it 'returns false for invalid templates' do
      %w[producer songwriter invalid_type].each do |type|
        expect(TemplateDetector.valid_template?(type)).to be false
      end
    end
    
    it 'handles nil and empty values' do
      expect(TemplateDetector.valid_template?(nil)).to be false
      expect(TemplateDetector.valid_template?('')).to be false
    end
  end
end