require 'rails_helper'

RSpec.describe Comment, type: :model do
  describe 'validations' do
    it 'requires content to be present' do
      comment = Comment.new(content: nil)
      expect(comment).not_to be_valid
      expect(comment.errors[:content]).to include("can't be blank")
    end

    it 'requires content not to be empty' do
      comment = Comment.new(content: '')
      expect(comment).not_to be_valid
      expect(comment.errors[:content]).to include("can't be blank")
    end

    it 'is valid with all required attributes' do
      comment = build(:comment)
      expect(comment).to be_valid
    end

    it 'accepts very long content' do
      long_content = 'A' * 10000
      comment = build(:comment, content: long_content)
      expect(comment).to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:track_version) }

    it 'belongs to a user' do
      user = create(:user)
      comment = create(:comment, user: user)

      expect(comment.user).to eq(user)
      expect(user.comments).to include(comment)
    end

    it 'belongs to a track version' do
      track_version = create(:track_version)
      comment = create(:comment, track_version: track_version)

      expect(comment.track_version).to eq(track_version)
      expect(track_version.comments).to include(comment)
    end
  end

  describe 'comment creation and ownership' do
    it 'can be created by any user on any track version' do
      user1 = create(:user)
      user2 = create(:user)
      track_version = create(:track_version)

      comment1 = create(:comment, user: user1, track_version: track_version)
      comment2 = create(:comment, user: user2, track_version: track_version)

      expect(comment1.user).to eq(user1)
      expect(comment2.user).to eq(user2)
      expect(track_version.comments).to include(comment1, comment2)
    end

    it 'allows multiple comments from the same user on the same track version' do
      user = create(:user)
      track_version = create(:track_version)

      comment1 = create(:comment, user: user, track_version: track_version, content: 'First comment')
      comment2 = create(:comment, user: user, track_version: track_version, content: 'Second comment')

      expect(user.comments).to include(comment1, comment2)
      expect(track_version.comments).to include(comment1, comment2)
    end
  end

  describe 'content handling' do
    it 'can store simple text content' do
      content = 'Great track! Love the melody.'
      comment = create(:comment, content: content)
      expect(comment.content).to eq(content)
    end

    it 'can store multiline content' do
      content = "This is a multiline comment.\nSecond line here.\nThird line with details."
      comment = create(:comment, content: content)
      expect(comment.content).to eq(content)
    end

    it 'can store content with special characters' do
      content = "Amazing track! 🎵 The beat at 2:30 is 🔥. Maybe add more reverb on the vocals?"
      comment = create(:comment, content: content)
      expect(comment.content).to eq(content)
    end

    it 'can store content with HTML-like text' do
      content = "The <strong>drums</strong> sound great, but the <em>bass</em> needs work."
      comment = create(:comment, content: content)
      expect(comment.content).to eq(content)
    end

    it 'can store content with markdown-like text' do
      content = "**Bold feedback**: This is *really* good! Here's my list:\n1. Great melody\n2. Need more bass\n3. Perfect tempo"
      comment = create(:comment, content: content)
      expect(comment.content).to eq(content)
    end

    it 'preserves whitespace in content' do
      content = "   Indented comment with    multiple spaces   and newlines\n\n\n"
      comment = create(:comment, content: content)
      expect(comment.content).to eq(content)
    end
  end

  describe 'comment threading and relationships' do
    let(:track_version) { create(:track_version) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:user3) { create(:user) }

    it 'multiple users can comment on the same track version' do
      comment1 = create(:comment, track_version: track_version, user: user1, content: 'Love it!')
      comment2 = create(:comment, track_version: track_version, user: user2, content: 'Needs work')
      comment3 = create(:comment, track_version: track_version, user: user3, content: 'Great job!')

      expect(track_version.comments).to include(comment1, comment2, comment3)
      expect(track_version.comments.count).to eq(3)
    end

    it 'can retrieve comments in chronological order' do
      comment1 = create(:comment, track_version: track_version, user: user1, created_at: 3.hours.ago)
      comment2 = create(:comment, track_version: track_version, user: user2, created_at: 1.hour.ago)
      comment3 = create(:comment, track_version: track_version, user: user3, created_at: 2.hours.ago)

      chronological_comments = track_version.comments.order(:created_at)
      expect(chronological_comments).to eq([comment1, comment3, comment2])
    end

    it 'can retrieve comments by user' do
      create(:comment, track_version: track_version, user: user1, content: 'User 1 first comment')
      create(:comment, track_version: track_version, user: user2, content: 'User 2 comment')
      create(:comment, track_version: track_version, user: user1, content: 'User 1 second comment')

      user1_comments = user1.comments
      expect(user1_comments.count).to eq(2)
      expect(user1_comments.pluck(:content)).to include('User 1 first comment', 'User 1 second comment')
    end
  end

  describe 'data integrity and cascading' do
    it 'is destroyed when track version is destroyed' do
      track_version = create(:track_version)
      comment = create(:comment, track_version: track_version)

      expect { track_version.destroy }.to change(Comment, :count).by(-1)
    end

    it 'is destroyed when user is destroyed' do
      user = create(:user)
      comment = create(:comment, user: user)

      expect { user.destroy }.to change(Comment, :count).by(-1)
    end

    it 'maintains referential integrity' do
      comment = create(:comment)
      
      # Verify relationships exist
      expect(comment.user).to be_present
      expect(comment.track_version).to be_present
      expect(comment.track_version.project).to be_present
    end
  end

  describe 'querying and filtering' do
    let(:project) { create(:project) }
    let(:track_version1) { create(:track_version, project: project) }
    let(:track_version2) { create(:track_version, project: project) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    before do
      create(:comment, track_version: track_version1, user: user1, content: 'Great track!')
      create(:comment, track_version: track_version1, user: user2, content: 'Needs improvement')
      create(:comment, track_version: track_version2, user: user1, content: 'Love this version')
    end

    it 'can find comments by track version' do
      tv1_comments = track_version1.comments
      expect(tv1_comments.count).to eq(2)
      expect(tv1_comments.pluck(:content)).to contain_exactly('Great track!', 'Needs improvement')
    end

    it 'can find comments by user' do
      user1_comments = user1.comments
      expect(user1_comments.count).to eq(2)
      expect(user1_comments.pluck(:content)).to contain_exactly('Great track!', 'Love this version')
    end

    it 'can search comments by content' do
      matching_comments = Comment.where('content ILIKE ?', '%great%')
      expect(matching_comments.count).to eq(1)
      expect(matching_comments.first.content).to eq('Great track!')
    end

    it 'can find all comments for a project through track versions' do
      project_comments = Comment.joins(:track_version).where(track_versions: { project: project })
      expect(project_comments.count).to eq(3)
    end
  end

  describe 'timestamps' do
    it 'sets created_at when comment is created' do
      comment = create(:comment)
      expect(comment.created_at).to be_present
      expect(comment.created_at).to be_within(1.second).of(Time.current)
    end

    it 'updates updated_at when comment is modified' do
      comment = create(:comment)
      original_updated_at = comment.updated_at
      
      sleep 0.1 # Ensure time difference
      comment.update!(content: 'Updated comment content')
      
      expect(comment.updated_at).to be > original_updated_at
    end

    it 'can order comments by creation time' do
      track_version = create(:track_version)
      
      old_comment = create(:comment, track_version: track_version, created_at: 1.day.ago)
      new_comment = create(:comment, track_version: track_version, created_at: 1.hour.ago)
      
      ordered_comments = track_version.comments.order(:created_at)
      expect(ordered_comments.first).to eq(old_comment)
      expect(ordered_comments.last).to eq(new_comment)
    end
  end

  describe 'edge cases' do
    it 'handles very long comments' do
      very_long_content = 'A' * 50000
      comment = create(:comment, content: very_long_content)
      expect(comment.content.length).to eq(50000)
    end

    it 'handles comments with only whitespace as invalid' do
      comment = build(:comment, content: '   ')
      expect(comment).not_to be_valid
    end

    it 'handles unicode content correctly' do
      unicode_content = '这是一个测试评论 🎵 with émojis and spëcial characters'
      comment = create(:comment, content: unicode_content)
      expect(comment.content).to eq(unicode_content)
    end

    it 'handles newlines and formatting characters' do
      formatted_content = "Line 1\nLine 2\r\nLine 3\tTabbed content\n\nDouble newline"
      comment = create(:comment, content: formatted_content)
      expect(comment.content).to eq(formatted_content)
    end
  end

  describe 'comment context and relationships' do
    it 'can access project through track version' do
      project = create(:project)
      track_version = create(:track_version, project: project)
      comment = create(:comment, track_version: track_version)

      expect(comment.track_version.project).to eq(project)
    end

    it 'can access workspace through project and track version' do
      workspace = create(:workspace)
      project = create(:project, workspace: workspace)
      track_version = create(:track_version, project: project)
      comment = create(:comment, track_version: track_version)

      expect(comment.track_version.project.workspace).to eq(workspace)
    end
  end

  describe 'data persistence' do
    it 'persists correctly to database' do
      comment = create(:comment, content: 'Test persistence comment')
      
      # Reload from database
      reloaded_comment = Comment.find(comment.id)
      
      expect(reloaded_comment.content).to eq('Test persistence comment')
      expect(reloaded_comment.user_id).to eq(comment.user_id)
      expect(reloaded_comment.track_version_id).to eq(comment.track_version_id)
    end
  end
end