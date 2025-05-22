# backend/spec/models/user_preference_spec.rb
RSpec.describe UserPreference, type: :model do
  describe 'validations' do
    it 'requires user_id to be present' do
      preference = UserPreference.new(user_id: nil)
      expect(preference).not_to be_valid
      expect(preference.errors[:user_id]).to include("can't be blank")
    end

    it 'requires key to be present' do
      preference = UserPreference.new(key: nil)
      expect(preference).not_to be_valid
      expect(preference.errors[:key]).to include("can't be blank")
    end

    it 'requires unique key per user' do
      user = create(:user)
      create(:user_preference, user: user, key: 'workspace_order')
      
      duplicate_preference = build(:user_preference, user: user, key: 'workspace_order')
      expect(duplicate_preference).not_to be_valid
      expect(duplicate_preference.errors[:key]).to include('has already been taken')
    end

    it 'allows same key for different users' do
      user1 = create(:user)
      user2 = create(:user)
      
      preference1 = create(:user_preference, user: user1, key: 'workspace_order')
      preference2 = build(:user_preference, user: user2, key: 'workspace_order')
      
      expect(preference2).to be_valid
    end

    it 'is valid with all required attributes' do
      preference = build(:user_preference)
      expect(preference).to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:user) }

    it 'belongs to a user' do
      user = create(:user)
      preference = create(:user_preference, user: user)

      expect(preference.user).to eq(user)
      expect(user.user_preferences).to include(preference)
    end
  end

  describe 'constants' do
    it 'defines workspace order constant' do
      expect(UserPreference::WORKSPACE_ORDER).to eq('workspace_order')
    end

    it 'defines favorite workspaces constant' do
      expect(UserPreference::FAVORITE_WORKSPACES).to eq('favorite_workspaces')
    end

    it 'defines private workspaces constant' do
      expect(UserPreference::PRIVATE_WORKSPACES).to eq('private_workspaces')
    end

    it 'defines collapsed sections constant' do
      expect(UserPreference::COLLAPSED_SECTIONS).to eq('collapsed_sections')
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }

    before do
      create(:user_preference, user: user, key: UserPreference::WORKSPACE_ORDER)
      create(:user_preference, user: user, key: UserPreference::FAVORITE_WORKSPACES)
      create(:user_preference, user: user, key: 'custom_preference')
    end

    it 'can find workspace order preferences' do
      workspace_orders = UserPreference.workspace_orders
      expect(workspace_orders.count).to eq(1)
      expect(workspace_orders.first.key).to eq(UserPreference::WORKSPACE_ORDER)
    end

    it 'can find favorite workspace preferences' do
      favorites = UserPreference.favorite_workspaces
      expect(favorites.count).to eq(1)
      expect(favorites.first.key).to eq(UserPreference::FAVORITE_WORKSPACES)
    end

    it 'can find private workspace preferences' do
      create(:user_preference, user: user, key: UserPreference::PRIVATE_WORKSPACES)
      privates = UserPreference.private_workspaces
      expect(privates.count).to eq(1)
      expect(privates.first.key).to eq(UserPreference::PRIVATE_WORKSPACES)
    end

    it 'can find collapsed section preferences' do
      create(:user_preference, user: user, key: UserPreference::COLLAPSED_SECTIONS)
      collapsed = UserPreference.collapsed_sections
      expect(collapsed.count).to eq(1)
      expect(collapsed.first.key).to eq(UserPreference::COLLAPSED_SECTIONS)
    end
  end

  describe 'value serialization' do
    it 'can store simple string values' do
      preference = create(:user_preference, value: 'simple_value')
      expect(preference.value).to eq('simple_value')
    end

    it 'can store array values' do
      workspace_order = [1, 3, 2, 5]
      preference = create(:user_preference, 
                         key: UserPreference::WORKSPACE_ORDER, 
                         value: workspace_order)
      
      expect(preference.value).to eq(workspace_order)
      expect(preference.value).to be_an(Array)
    end

    it 'can store hash values' do
      collapsed_sections = { 'favorites' => false, 'workspaces' => true, 'private' => false }
      preference = create(:user_preference, 
                         key: UserPreference::COLLAPSED_SECTIONS, 
                         value: collapsed_sections)
      
      expect(preference.value).to eq(collapsed_sections)
      expect(preference.value).to be_a(Hash)
      expect(preference.value['workspaces']).to be true
    end

    it 'can store complex nested data' do
      complex_data = {
        'ui_preferences' => {
          'theme' => 'dark',
          'sidebar_width' => 280
        },
        'workflow_settings' => {
          'auto_save' => true,
          'default_visibility' => 'private'
        }
      }
      
      preference = create(:user_preference, value: complex_data)
      expect(preference.value['ui_preferences']['theme']).to eq('dark')
      expect(preference.value['workflow_settings']['auto_save']).to be true
    end

    it 'handles nil values gracefully' do
      preference = create(:user_preference, value: nil)
      expect(preference.value).to be_nil
    end

    it 'handles empty arrays' do
      preference = create(:user_preference, value: [])
      expect(preference.value).to eq([])
      expect(preference.value).to be_an(Array)
    end

    it 'handles empty hashes' do
      preference = create(:user_preference, value: {})
      expect(preference.value).to eq({})
      expect(preference.value).to be_a(Hash)
    end
  end

  describe 'workspace preferences' do
    let(:user) { create(:user) }

    it 'can store workspace order preference' do
      workspace_ids = [5, 2, 8, 1]
      preference = create(:user_preference, 
                         user: user,
                         key: UserPreference::WORKSPACE_ORDER, 
                         value: workspace_ids)
      
      expect(preference.value).to eq(workspace_ids)
    end

    it 'can store favorite workspaces' do
      favorite_ids = [1, 3, 7]
      preference = create(:user_preference, 
                         user: user,
                         key: UserPreference::FAVORITE_WORKSPACES, 
                         value: favorite_ids)
      
      expect(preference.value).to eq(favorite_ids)
    end

    it 'can store private workspace settings' do
      private_ids = [2, 4]
      preference = create(:user_preference, 
                         user: user,
                         key: UserPreference::PRIVATE_WORKSPACES, 
                         value: private_ids)
      
      expect(preference.value).to eq(private_ids)
    end

    it 'can store collapsed section preferences' do
      sections = {
        'favorites' => true,
        'workspaces' => false,
        'private' => true
      }
      
      preference = create(:user_preference, 
                         user: user,
                         key: UserPreference::COLLAPSED_SECTIONS, 
                         value: sections)
      
      expect(preference.value).to eq(sections)
      expect(preference.value['favorites']).to be true
    end
  end

  describe 'class method get_workspace_preferences' do
    let(:user) { create(:user) }

    it 'returns default values when no preferences exist' do
      preferences = UserPreference.get_workspace_preferences(user)
      
      expect(preferences[:workspace_order]).to eq([])
      expect(preferences[:favorite_workspaces]).to eq([])
      expect(preferences[:private_workspaces]).to eq([])
      expect(preferences[:collapsed_sections]).to eq({
        favorites: false,
        workspaces: false,
        private: false
      })
    end

    it 'returns actual values when preferences exist' do
      create(:user_preference, user: user, key: UserPreference::WORKSPACE_ORDER, value: [1, 2, 3])
      create(:user_preference, user: user, key: UserPreference::FAVORITE_WORKSPACES, value: [1, 3])
      create(:user_preference, user: user, key: UserPreference::PRIVATE_WORKSPACES, value: [2])
      create(:user_preference, user: user, key: UserPreference::COLLAPSED_SECTIONS, value: { 'favorites' => true })

      preferences = UserPreference.get_workspace_preferences(user)
      
      expect(preferences[:workspace_order]).to eq([1, 2, 3])
      expect(preferences[:favorite_workspaces]).to eq([1, 3])
      expect(preferences[:private_workspaces]).to eq([2])
      expect(preferences[:collapsed_sections]).to eq({ 'favorites' => true })
    end

    it 'returns mixed actual and default values' do
      create(:user_preference, user: user, key: UserPreference::WORKSPACE_ORDER, value: [5, 1])

      preferences = UserPreference.get_workspace_preferences(user)
      
      expect(preferences[:workspace_order]).to eq([5, 1])
      expect(preferences[:favorite_workspaces]).to eq([]) # default
      expect(preferences[:private_workspaces]).to eq([]) # default
    end
  end

  describe 'data integrity' do
    it 'is destroyed when user is destroyed' do
      user = create(:user)
      preference = create(:user_preference, user: user)

      expect { user.destroy }.to change(UserPreference, :count).by(-1)
    end

    it 'maintains referential integrity' do
      preference = create(:user_preference)
      expect(preference.user).to be_present
    end
  end

  describe 'querying and filtering' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    before do
      create(:user_preference, user: user1, key: 'setting1', value: 'value1')
      create(:user_preference, user: user1, key: 'setting2', value: 'value2')
      create(:user_preference, user: user2, key: 'setting1', value: 'value3')
    end

    it 'can find preferences by user' do
      user1_preferences = user1.user_preferences
      expect(user1_preferences.count).to eq(2)
      expect(user1_preferences.pluck(:key)).to contain_exactly('setting1', 'setting2')
    end

    it 'can find preferences by key' do
      setting1_preferences = UserPreference.where(key: 'setting1')
      expect(setting1_preferences.count).to eq(2)
      expect(setting1_preferences.pluck(:value)).to contain_exactly('value1', 'value3')
    end

    it 'can find specific user preference by key' do
      preference = UserPreference.find_by(user: user1, key: 'setting1')
      expect(preference.value).to eq('value1')
    end
  end

  describe 'timestamps' do
    it 'sets created_at when preference is created' do
      preference = create(:user_preference)
      expect(preference.created_at).to be_present
      expect(preference.created_at).to be_within(1.second).of(Time.current)
    end

    it 'updates updated_at when preference is modified' do
      preference = create(:user_preference)
      original_updated_at = preference.updated_at
      
      sleep 0.1 # Ensure time difference
      preference.update!(value: 'updated_value')
      
      expect(preference.updated_at).to be > original_updated_at
    end
  end

  describe 'edge cases' do
    it 'handles very long keys' do
      long_key = 'a' * 200
      preference = build(:user_preference, key: long_key)
      expect(preference.key.length).to eq(200)
    end

    it 'handles complex data structures' do
      complex_value = {
        'arrays' => [1, 2, [3, 4]],
        'nested_hashes' => { 'level2' => { 'level3' => 'deep_value' } },
        'mixed_types' => [1, 'string', { 'key' => 'value' }, true, nil]
      }
      
      preference = create(:user_preference, value: complex_value)
      expect(preference.value['nested_hashes']['level2']['level3']).to eq('deep_value')
      expect(preference.value['arrays'][2]).to eq([3, 4])
    end

    it 'handles unicode in keys and values' do
      unicode_key = 'setting_🎵_音楽'
      unicode_value = { 'message' => 'Hello 世界! 🎶' }
      
      preference = create(:user_preference, key: unicode_key, value: unicode_value)
      expect(preference.key).to eq(unicode_key)
      expect(preference.value['message']).to eq('Hello 世界! 🎶')
    end
  end

  describe 'data persistence' do
    it 'persists correctly to database' do
      original_data = { 'test' => 'persistence', 'number' => 42 }
      preference = create(:user_preference, key: 'test_key', value: original_data)
      
      # Reload from database
      reloaded_preference = UserPreference.find(preference.id)
      
      expect(reloaded_preference.key).to eq('test_key')
      expect(reloaded_preference.value).to eq(original_data)
      expect(reloaded_preference.user_id).to eq(preference.user_id)
    end
  end
end